defmodule GasolineSimulator.Scenarios.Runner do
  alias GasolineSimulator.Data.Repository
  alias GasolineSimulator.Data.Catalog
  alias GasolineSimulator.Models.Overrides
  alias GasolineSimulator.Models.Problem
  alias GasolineSimulator.Models.Result
  alias GasolineSimulator.Refineries.Distances
  alias GasolineSimulator.Refineries.Logistics
  alias GasolineSimulator.Refineries.Plant
  alias GasolineSimulator.Refineries.Supervisor, as: PlantSupervisor
  alias GasolineSimulator.Scenarios.YieldSampling
  alias GasolineSimulator.Solver

  @default_min_year_ms 30_000

  @spec run(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def run(params \\ %{}, opts \\ []) do
    year_data = Repository.load_year(Keyword.take(opts, [:data_dir]))

    yields_for = Keyword.get(opts, :yields, &YieldSampling.draw/1)

    overrides = overrides(params)

    ctx = %{
      overrides: overrides,
      year_data: year_data,
      simulated_yields: yields_for.(year_data.refineries_by_day),
      solver_opts: Keyword.take(opts, [:timeout, :task_supervisor]),
      min_year_ms: Keyword.get(opts, :min_year_ms, @default_min_year_ms),
      alive_ids: Keyword.get(opts, :alive_ids, &default_alive_ids/1),
      on_day: Keyword.get(opts, :on_day, fn _day -> :ok end),
      burst: Keyword.get(opts, :burst_utilization_ratio, Problem.burst_utilization_ratio()),
      sustainable:
        Keyword.get(opts, :sustainable_utilization_ratio, Problem.sustainable_utilization_ratio()),
      failure_pct: Plant.failure_pct(param_failure_pct(params)),
      closed_roads: Keyword.get(opts, :closed_roads, fn _day -> [] end)
    }

    with {:ok, days} <- run_days(ctx) do
      {:ok,
       %{
         days: days,
         months: months_from_days(days),
         annual: summarize(days),
         simulated_yields: ctx.simulated_yields
       }}
    end
  end

  defp run_days(ctx) do
    run_id = make_ref()
    ctx = Map.put(ctx, :run_id, run_id)

    try do
      walk_days(ctx)
    after
      Logistics.clear(Catalog.ids(), run_id)
    end
  end

  defp walk_days(ctx) do
    days = Repository.days()
    day_count = length(days)
    started_at = System.monotonic_time(:millisecond)

    days
    |> Enum.with_index(1)
    |> Enum.reduce_while(empty_year(ctx), fn {day, index}, state ->
      {present, landed} = Logistics.landed(ctx.alive_ids.(day), day, ctx.run_id)
      alive = MapSet.new(present)
      open_plants(alive, ctx)
      rejoin_plants(state.prior, alive)

      result =
        day
        |> solve_day(landed, ctx, alive, state.planning_yield)
        |> maybe_dispatch(day, present, ctx)

      if result.status == :ok do
        ctx.on_day.(result)
        pace_year(started_at, index, day_count, ctx.min_year_ms)

        {:cont,
         state
         |> observe_yield(result)
         |> Map.put(:acc, [result | state.acc])
         |> Map.put(:prior, alive)}
      else
        {:halt, {:error, result}}
      end
    end)
    |> case do
      {:error, failed} -> {:error, failed}
      %{acc: acc} -> {:ok, Enum.reverse(acc)}
    end
  end

  defp maybe_dispatch(%{status: :ok} = result, day, present, ctx) do
    credit_gasoline(result.refineries, ctx.run_id)

    result
    |> Logistics.dispatch(day, present, ctx.run_id, ctx.failure_pct, closed_pairs(ctx, day))
    |> plant_stocks(ctx.run_id)
  end

  defp maybe_dispatch(result, _day, _present, _ctx), do: result

  defp closed_pairs(ctx, day) do
    ctx.closed_roads.(day)
    |> Enum.map(&Distances.pair/1)
    |> MapSet.new()
  end

  defp credit_gasoline(refineries, run_id) do
    Enum.each(refineries, fn refinery ->
      Plant.credit(refinery.id, refinery.allocated_m3, run_id)
    end)
  end

  defp plant_stocks(result, run_id) do
    stock_by_id = Map.new(Catalog.ids(), &{&1, plant_stock(&1, run_id)})

    refineries =
      Enum.map(result.refineries, fn refinery ->
        Map.put(refinery, :stock_m3, Map.get(stock_by_id, refinery.id, 0.0))
      end)

    %{result | refineries: refineries, stock_by_id: stock_by_id}
  end

  defp plant_stock(id, run_id) do
    case Plant.on_hand(id, run_id) do
      {:ok, volume} -> volume
      {:error, :absent} -> 0.0
    end
  end

  defp empty_year(_ctx) do
    %{acc: [], prior: :start, planning_yield: nil, gasoline_m3: 0.0, petroleum_m3: 0.0}
  end

  defp observe_yield(state, result) do
    gasoline_m3 = state.gasoline_m3 + result.production_m3
    petroleum_m3 = state.petroleum_m3 + result.total_petroleum_processed_m3

    planning_yield =
      if petroleum_m3 > 0.0, do: gasoline_m3 / petroleum_m3, else: state.planning_yield

    %{state | gasoline_m3: gasoline_m3, petroleum_m3: petroleum_m3, planning_yield: planning_yield}
  end

  defp default_alive_ids(_day), do: PlantSupervisor.alive_ids()

  defp open_plants(alive, ctx) do
    Enum.each(alive, &Plant.open_run(&1, ctx.run_id, ctx.burst, ctx.sustainable))
  end

  defp rejoin_plants(:start, _alive), do: :ok

  defp rejoin_plants(prior, alive) do
    alive
    |> MapSet.difference(prior)
    |> Enum.each(&Plant.rejoin/1)
  end

  defp pace_year(_started_at, _index, _day_count, min_year_ms) when min_year_ms <= 0, do: :ok

  defp pace_year(started_at, index, day_count, min_year_ms) do
    target = started_at + div(index * min_year_ms, day_count)
    wait = target - System.monotonic_time(:millisecond)
    if wait > 0, do: Process.sleep(wait)
    :ok
  end

  defp solve_day(day, landed, ctx, alive, planning_yield) do
    result = chosen_day(day, landed, ctx, alive, planning_yield)
    hear_plants(result, ctx.run_id)
    result
  end

  defp chosen_day(day, landed, ctx, alive, planning_yield) do
    day_yields = Map.fetch!(ctx.simulated_yields, day)
    demand = Map.fetch!(ctx.year_data.demand_by_day, day).demand_m3

    refineries =
      ctx.year_data.refineries_by_day
      |> Map.fetch!(day)
      |> Enum.filter(&MapSet.member?(alive, &1.id))
      |> Enum.map(fn refinery ->
        refinery
        |> Map.put(:simulated_yield, Map.fetch!(day_yields, refinery.id))
        |> Map.put(:min_utilization_ratio, Plant.floor_ratio(refinery.id))
        |> Map.put(:max_utilization_ratio, ctx.burst)
      end)

    problem =
      Problem.build(%{
        month: Repository.day_key(day),
        demand_m3: adjusted_demand(ctx.overrides, demand),
        landed_m3: landed,
        planning_yield: planning_yield,
        refineries: refineries
      })

    Result.from_solver(problem, Solver.solve(Problem.to_solver_input(problem), ctx.solver_opts))
  end

  defp hear_plants(%{status: :ok} = result, run_id) do
    Enum.each(result.refineries, fn refinery ->
      Plant.hear(refinery.id, %{
        run_id: run_id,
        deficit_m3: result.deficit_m3,
        planned_m3: refinery.planned_m3
      })
    end)
  end

  defp hear_plants(_result, _run_id), do: []

  defp param_failure_pct(params) when is_map(params) do
    Map.get(params, :failure_pct) || Map.get(params, "failure_pct") || %{}
  end

  defp param_failure_pct(_params), do: %{}

  defp overrides(params) do
    values =
      params
      |> Map.take(Map.keys(%Overrides{}))
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()

    overrides = struct!(Overrides, values)
    overrides
  end

  defp adjusted_demand(%Overrides{demand_adjustment_pct: pct}, demand_m3),
    do: demand_m3 * (1.0 + pct / 100.0)

  defp months_from_days(days) do
    days
    |> Enum.group_by(&month_label(&1.month))
    |> Enum.sort_by(fn {month, _days} -> month end)
    |> Enum.map(fn {month, month_days} ->
      totals = summarize(month_days)

      Map.merge(totals, %{
        status: :ok,
        month: month,
        refineries: aggregate_refineries(month_days)
      })
    end)
  end

  defp month_label(day_key), do: String.slice(day_key, 0, 7)

  defp aggregate_refineries(days) do
    days
    |> Enum.flat_map(& &1.refineries)
    |> Enum.group_by(& &1.id)
    |> Enum.map(fn {_id, rows} ->
      first = hd(rows)
      allocated = sum(rows, :allocated_m3)
      petroleum = sum(rows, :petroleum_processed_m3)
      other_charges = sum(rows, :other_charges_m3)
      processing_capacity = sum(rows, :processing_capacity_m3)
      yield = allocated / petroleum

      %{
        id: first.id,
        name: first.name,
        uf: first.uf,
        allocated_m3: allocated,
        petroleum_processed_m3: petroleum,
        other_charges_m3: other_charges,
        processing_capacity_m3: processing_capacity,
        capacity_m3: sum(rows, :capacity_m3),
        floor_m3: sum(rows, :floor_m3),
        simulated_yield: yield,
        active: Enum.any?(rows, & &1.active),
        fut_pct: (petroleum + other_charges) / processing_capacity * 100.0
      }
    end)
    |> Enum.sort_by(& &1.id)
  end

  defp summarize(periods) do
    demand_m3 = sum(periods, :demand_m3)
    production_m3 = sum(periods, :production_m3)
    served_demand_m3 = sum(periods, :served_demand_m3)
    petroleum = sum(periods, :total_petroleum_processed_m3)
    other_charges = sum(periods, :total_other_charges_m3)
    capacity = sum(periods, :total_processing_capacity_m3)

    %{
      demand_m3: demand_m3,
      production_m3: production_m3,
      served_demand_m3: served_demand_m3,
      deficit_m3: sum(periods, :deficit_m3),
      total_petroleum_processed_m3: petroleum,
      total_other_charges_m3: other_charges,
      total_processing_capacity_m3: capacity,
      balance_m3: production_m3 - demand_m3,
      total_fut_pct: (petroleum + other_charges) / capacity * 100.0,
      landed_m3: sum(periods, :landed_m3),
      excess_m3: sum(periods, :excess_m3),
      plant_stock_m3: plant_stock_total(List.last(periods)),
      coverage: served_demand_m3 / demand_m3
    }
  end

  defp sum(periods, field), do: Enum.sum_by(periods, &Map.fetch!(&1, field))

  defp plant_stock_total(%{stock_by_id: stocks}) when is_map(stocks), do: Enum.sum(Map.values(stocks))
  defp plant_stock_total(_period), do: 0.0
end
