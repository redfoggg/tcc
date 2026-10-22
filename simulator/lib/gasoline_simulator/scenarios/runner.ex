defmodule GasolineSimulator.Scenarios.Runner do
  alias GasolineSimulator.Data.Regions
  alias GasolineSimulator.Data.Repository
  alias GasolineSimulator.Data.Catalog
  alias GasolineSimulator.Models.Overrides
  alias GasolineSimulator.Models.Problem
  alias GasolineSimulator.Models.Result
  alias GasolineSimulator.Refineries.Distances
  alias GasolineSimulator.Refineries.Fleet
  alias GasolineSimulator.Refineries.Logistics
  alias GasolineSimulator.Refineries.Plant
  alias GasolineSimulator.Refineries.Supervisor, as: PlantSupervisor
  alias GasolineSimulator.Scenarios.Seed
  alias GasolineSimulator.Scenarios.YieldSampling
  alias GasolineSimulator.Solver

  @default_min_year_ms 30_000

  @spec run(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def run(params, opts) do
    seed = Keyword.get(opts, :seed)
    seed_path = Keyword.get(opts, :seed_path)
    Seed.plant(seed, {:runner, seed_path})

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
      failure_pct: params.failure_pct,
      closed_roads: Keyword.get(opts, :closed_roads, fn _day -> [] end),
      on_fleet: Keyword.get(opts, :on_fleet, fn _fleet -> :ok end),
      observe_deliveries: Keyword.get(opts, :observe_deliveries, false),
      seed: seed,
      seed_path: seed_path
    }

    ctx = Map.merge(ctx, %{forecast: forecast(ctx), days_after: days_after()})

    with {:ok, days, lost_m3} <- run_days(ctx) do
      {:ok,
       %{
         days: days,
         months: months_from_days(days),
         annual: year_coverage(summarize(days), lost_m3),
         simulated_yields: ctx.simulated_yields
       }}
    end
  end

  defp run_days(ctx) do
    run_id = make_ref()
    fleet = Fleet.start(run_id, Catalog.ids(), ctx.observe_deliveries, ctx.seed, ctx.seed_path)
    ctx.on_fleet.(fleet)

    try do
      walk_days(Map.put(ctx, :run_id, run_id))
    after
      Fleet.stop(fleet)
    end
  end

  defp walk_days(ctx) do
    days = Repository.days()
    day_count = length(days)
    started_at = System.monotonic_time(:millisecond)

    days
    |> Enum.with_index(1)
    |> Enum.reduce_while(empty_year(ctx), fn {day, index}, state ->
      {present, landed, landed_by_region, landed_by_plant} =
        Logistics.landed(ctx.alive_ids.(day), day, ctx.run_id)

      alive = MapSet.new(present)
      opening_by_id = opening_stock(ctx.run_id)
      open_plants(alive, ctx)
      rejoin_plants(state.prior, alive, ctx.run_id)

      {result, carried_deficit} =
        day
        |> solve_day(
          landed,
          landed_by_region,
          ctx,
          alive,
          state.planning_yield,
          state.carried_deficit,
          by_region(opening_by_id),
          state.plant_catch_up
        )
        |> maybe_dispatch(
          day,
          present,
          ctx,
          state.carried_deficit,
          landed_by_region,
          opening_by_id,
          landed_by_plant
        )

      if result.status == :ok do
        ctx.on_day.(result)
        pace_year(started_at, index, day_count, ctx.min_year_ms)

        {:cont,
         state
         |> observe_yield(result)
         |> Map.put(:acc, [result | state.acc])
         |> Map.put(:prior, alive)
         |> Map.put(:carried_deficit, carried_deficit)
         |> Map.put(:plant_catch_up, plant_reaction(state.plant_catch_up, result))}
      else
        {:halt, {:error, result}}
      end
    end)
    |> case do
      {:error, failed} -> {:error, failed}
      %{acc: acc} -> {:ok, Enum.reverse(acc), transport_losses(ctx.run_id)}
    end
  end

  defp maybe_dispatch(
         %{status: :ok} = result,
         day,
         present,
         ctx,
         _carried_deficit,
         landed_by_region,
         opening_by_id,
         landed_by_plant
       ) do
    credit_gasoline(result.refineries, ctx.run_id)
    credit_landed(landed_by_plant, ctx.run_id)

    {result, {_shipped, shipped_by_region}} =
      Logistics.dispatch(
        result,
        day,
        present,
        ctx.run_id,
        ctx.failure_pct,
        closed_pairs(ctx, day),
        landed_by_plant
      )

    opening_by_region = by_region(opening_by_id)

    result =
      result
      |> Result.cover_regions(shipped_by_region, landed_by_region, opening_by_region)
      |> tap(&hear_plants(&1, ctx.run_id))

    retain_excess(ctx.run_id, result.demand_m3)
    result = plant_stocks(result, ctx.run_id)
    {result, result.deficit_m3}
  end

  defp maybe_dispatch(
         result,
         _day,
         _present,
         _ctx,
         carried_deficit,
         _landed_by_region,
         _opening_by_id,
         _landed_by_plant
       ) do
    {result, carried_deficit}
  end

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

  defp credit_landed(landed_by_plant, run_id) do
    Enum.each(landed_by_plant, fn {id, volume} -> Plant.credit(id, volume, run_id) end)
  end

  defp opening_stock(run_id) do
    Map.new(Catalog.ids(), &{&1, plant_stock(&1, run_id)})
  end

  defp by_region(stock_by_id) do
    Enum.reduce(stock_by_id, %{}, fn {id, volume}, acc ->
      Map.update(acc, Regions.of_plant(id), volume, &(&1 + volume))
    end)
  end

  defp retain_excess(run_id, demand_m3) do
    Enum.each(Regions.ids(), fn region ->
      held =
        Catalog.ids()
        |> Enum.filter(&(Regions.of_plant(&1) == region))
        |> Enum.map(&{&1, plant_stock(&1, run_id)})
        |> Enum.filter(fn {_id, volume} -> volume > 0.0 end)

      total = Enum.sum_by(held, &elem(&1, 1))
      draw = min(total, Regions.demand(demand_m3, region))

      if total > 0.0 and draw > 0.0 do
        Enum.each(held, fn {id, volume} -> Plant.draw(id, draw * volume / total, run_id) end)
      end
    end)
  end

  defp plant_stocks(result, run_id) do
    stock_by_id = Map.new(Catalog.ids(), &{&1, plant_stock(&1, run_id)})

    refineries =
      Enum.map(result.refineries, fn refinery ->
        Map.put(refinery, :stock_m3, Map.fetch!(stock_by_id, refinery.id))
      end)

    %{result | refineries: refineries, stock_by_id: stock_by_id}
  end

  defp plant_stock(id, run_id) do
    case Plant.on_hand(id, run_id) do
      {:ok, volume} -> volume
      {:error, :absent} -> 0.0
    end
  end

  defp empty_year(ctx) do
    %{
      acc: [],
      prior: :start,
      planning_yield: ctx.year_data.national_average_yield,
      gasoline_m3: 0.0,
      petroleum_m3: 0.0,
      carried_deficit: 0.0,
      plant_catch_up: %{}
    }
  end

  defp observe_yield(state, result) do
    gasoline_m3 = state.gasoline_m3 + result.production_m3
    petroleum_m3 = state.petroleum_m3 + result.total_petroleum_processed_m3

    planning_yield =
      if petroleum_m3 > 0.0, do: gasoline_m3 / petroleum_m3, else: state.planning_yield

    %{
      state
      | gasoline_m3: gasoline_m3,
        petroleum_m3: petroleum_m3,
        planning_yield: planning_yield
    }
  end

  defp default_alive_ids(_day), do: PlantSupervisor.alive_ids()

  defp open_plants(alive, ctx) do
    Enum.each(alive, &Plant.open_run(&1, ctx.run_id, ctx.burst, ctx.sustainable))
  end

  defp rejoin_plants(:start, _alive, _run_id), do: :ok

  defp rejoin_plants(prior, alive, run_id) do
    alive
    |> MapSet.difference(prior)
    |> Enum.each(&Plant.rejoin(&1, run_id))
  end

  defp pace_year(_started_at, _index, _day_count, min_year_ms) when min_year_ms <= 0, do: :ok

  defp pace_year(started_at, index, day_count, min_year_ms) do
    target = started_at + div(index * min_year_ms, day_count)
    wait = target - System.monotonic_time(:millisecond)
    if wait > 0, do: Process.sleep(wait)
    :ok
  end

  defp solve_day(
         day,
         landed,
         landed_by_region,
         ctx,
         alive,
         planning_yield,
         carried_deficit,
         stock_by_region,
         plant_catch_up
       ) do
    chosen_day(
      day,
      landed,
      landed_by_region,
      ctx,
      alive,
      planning_yield,
      carried_deficit,
      stock_by_region,
      plant_catch_up
    )
  end

  defp chosen_day(
         day,
         landed,
         landed_by_region,
         ctx,
         alive,
         planning_yield,
         carried_deficit,
         stock_by_region,
         plant_catch_up
       ) do
    day_yields = Map.fetch!(ctx.simulated_yields, day)
    demand = Map.fetch!(ctx.year_data.demand_by_day, day).demand_m3

    refineries =
      ctx.year_data.refineries_by_day
      |> Map.fetch!(day)
      |> Enum.filter(&MapSet.member?(alive, &1.id))
      |> Enum.map(fn refinery ->
        refinery
        |> Map.put(:simulated_yield, Map.fetch!(day_yields, refinery.id))
        |> Map.put(
          :min_utilization_ratio,
          catch_up_ratio(refinery, planning_yield, ctx, plant_catch_up)
        )
        |> Map.put(:max_utilization_ratio, ctx.burst)
      end)

    problem =
      Problem.build(%{
        month: Repository.day_key(day),
        demand_m3: adjusted_demand(ctx.overrides, day, demand),
        landed_m3: landed,
        landed_by_region: landed_by_region,
        carried_deficit_m3: carried_deficit,
        reserve_m3: reserve(ctx, day, planning_yield),
        stock_by_region: stock_by_region,
        planning_yield: planning_yield,
        refineries: refineries
      })

    Result.from_solver(problem, Solver.solve(Problem.to_solver_input(problem), ctx.solver_opts))
  end

  defp forecast(ctx) do
    Map.new(Repository.days(), fn day ->
      demand = adjusted_demand(ctx.overrides, day, ctx.year_data.demand_by_day[day].demand_m3)

      ceiling =
        Enum.sum_by(ctx.year_data.refineries_by_day[day], fn refinery ->
          max(ctx.burst * refinery.processing_capacity_m3 - refinery.other_charges_m3, 0.0)
        end)

      {day, {demand, ceiling}}
    end)
  end

  defp reserve(ctx, day, planning_yield) do
    ctx.days_after
    |> Map.fetch!(day)
    |> Enum.reduce(0.0, fn later, ahead ->
      {demand, ceiling} = Map.fetch!(ctx.forecast, later)
      max(ahead + demand - ceiling * planning_yield, 0.0)
    end)
  end

  defp days_after do
    days = Repository.days()

    days
    |> Enum.with_index(1)
    |> Map.new(fn {day, i} -> {day, days |> Enum.drop(i) |> Enum.reverse()} end)
  end

  defp catch_up_ratio(refinery, planning_yield, ctx, plant_catch_up) do
    base = Plant.floor_ratio(refinery.id, ctx.run_id)
    owed = Map.get(plant_catch_up, refinery.id, 0.0)
    extra = owed / planning_yield / refinery.processing_capacity_m3
    min(ctx.burst, base + extra)
  end

  defp plant_reaction(catch_up, %{refineries: refineries}) do
    Map.new(refineries, fn refinery ->
      owed = Map.get(catch_up, refinery.id, 0.0)
      {refinery.id, max(0.0, owed + refinery.planned_m3 - refinery.allocated_m3)}
    end)
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

  defp overrides(params) do
    values =
      params
      |> Map.take(Map.keys(%Overrides{}))
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()

    overrides = struct!(Overrides, values)
    overrides
  end

  defp adjusted_demand(%Overrides{} = overrides, day, demand_m3) do
    pct = Map.get(overrides.demand_by_month, day.month, overrides.demand_adjustment_pct)
    demand_m3 * (1.0 + pct / 100.0)
  end

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
      plant_stock_m3:
        periods |> List.last() |> Map.fetch!(:stock_by_id) |> Map.values() |> Enum.sum(),
      coverage: served_demand_m3 / demand_m3,
      regions: regional_totals(periods)
    }
  end

  defp regional_totals(periods) do
    stock_by_region = periods |> List.last() |> Map.fetch!(:stock_by_id) |> by_region()

    Enum.map(Regions.ids(), fn id ->
      rows =
        periods
        |> Enum.flat_map(& &1.regions)
        |> Enum.filter(&(&1.id == id))

      demand_m3 = Enum.sum_by(rows, & &1.demand_m3)
      produced_m3 = Enum.sum_by(rows, & &1.produced_m3)
      supply_m3 = Enum.sum_by(rows, & &1.supply_m3)
      served_m3 = min(demand_m3, supply_m3)

      %{
        id: id,
        demand_m3: demand_m3,
        produced_m3: produced_m3,
        served_m3: served_m3,
        stock_m3: Map.fetch!(stock_by_region, id),
        coverage: if(demand_m3 == 0.0, do: 0.0, else: served_m3 / demand_m3)
      }
    end)
  end

  defp year_coverage(annual, lost_m3) do
    available = annual.production_m3 - lost_m3
    served = min(annual.demand_m3, available)
    deficit = max(annual.demand_m3 - available, 0.0)
    excess = max(available - annual.demand_m3, 0.0)
    effective = Enum.sum_by(annual.regions, & &1.served_m3)

    Map.merge(annual, %{
      lost_m3: lost_m3,
      served_demand_m3: served,
      deficit_m3: deficit,
      excess_m3: excess,
      coverage: share(served, annual.demand_m3),
      effective_served_m3: effective,
      effective_coverage: share(effective, annual.demand_m3)
    })
  end

  defp share(_part, total) when total == 0.0, do: 0.0
  defp share(part, total), do: part / total

  defp sum(periods, field), do: Enum.sum_by(periods, &Map.fetch!(&1, field))

  defp transport_losses(run_id) do
    Enum.sum_by(Catalog.ids(), fn id ->
      case Plant.lost_m3(id, run_id) do
        {:ok, volume} -> volume
        {:error, :absent} -> 0.0
      end
    end)
  end
end
