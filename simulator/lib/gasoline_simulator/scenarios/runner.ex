defmodule GasolineSimulator.Scenarios.Runner do
  alias GasolineSimulator.Data.Repository
  alias GasolineSimulator.Models.Overrides
  alias GasolineSimulator.Models.Problem
  alias GasolineSimulator.Models.Result
  alias GasolineSimulator.Refineries.Supervisor, as: PlantSupervisor
  alias GasolineSimulator.Scenarios.YieldSampling
  alias GasolineSimulator.Solver

  @default_min_year_ms 30_000

  @spec run(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def run(params \\ %{}, opts \\ []) do
    year_data = Repository.load_year(Keyword.take(opts, [:data_dir]))

    ctx = %{
      overrides: overrides(params),
      year_data: year_data,
      simulated_yields: YieldSampling.draw(year_data.refineries_by_day),
      solver_opts: Keyword.take(opts, [:timeout, :task_supervisor]),
      min_year_ms: Keyword.get(opts, :min_year_ms, @default_min_year_ms),
      alive_ids: Keyword.get(opts, :alive_ids, &default_alive_ids/1),
      on_day: Keyword.get(opts, :on_day, fn _day -> :ok end)
    }

    with {:ok, days} <- run_days(ctx) do
      {:ok, %{days: days, months: months_from_days(days), annual: summarize(days)}}
    end
  end

  @ratio_step 0.01
  @burst_hit_ratio 0.99

  defp run_days(ctx) do
    days = Repository.days()
    day_count = length(days)
    started_at = System.monotonic_time(:millisecond)

    days
    |> Enum.with_index(1)
    |> Enum.reduce_while(empty_year(ctx), fn {day, index}, state ->
      alive = MapSet.new(ctx.alive_ids.(day))
      pace = apply_rejoins(state.pace, state.prior, alive)
      result = solve_day(day, state.opening, pace, ctx, alive)

      if result.status == :ok do
        ctx.on_day.(result)
        pace_year(started_at, index, day_count, ctx.min_year_ms)

        {:cont,
         %{
           acc: [result | state.acc],
           opening: result.ending_inventory_m3,
           pace: update_pace(pace, result),
           prior: alive
         }}
      else
        {:halt, {:error, result}}
      end
    end)
    |> case do
      {:error, failed} -> {:error, failed}
      %{acc: acc} -> {:ok, Enum.reverse(acc)}
    end
  end

  defp empty_year(ctx) do
    %{acc: [], opening: ctx.overrides.initial_inventory_m3, pace: %{}, prior: :start}
  end

  defp default_alive_ids(_day), do: PlantSupervisor.alive_ids()

  defp apply_rejoins(pace, :start, _alive), do: pace

  defp apply_rejoins(pace, prior, alive) do
    Enum.reduce(MapSet.difference(alive, prior), pace, fn id, acc ->
      Map.put(acc, id, new_pace(:ramping))
    end)
  end

  defp pace_year(_started_at, _index, _day_count, min_year_ms) when min_year_ms <= 0, do: :ok

  defp pace_year(started_at, index, day_count, min_year_ms) do
    target = started_at + div(index * min_year_ms, day_count)
    wait = target - System.monotonic_time(:millisecond)
    if wait > 0, do: Process.sleep(wait)
    :ok
  end

  defp solve_day(day, opening, pace, ctx, alive) do
    day_yields = Map.fetch!(ctx.simulated_yields, day)
    demand = Map.fetch!(ctx.year_data.demand_by_day, day).demand_m3

    refineries =
      ctx.year_data.refineries_by_day
      |> Map.fetch!(day)
      |> Enum.filter(&MapSet.member?(alive, &1.id))
      |> Enum.map(fn refinery ->
        refinery
        |> Map.put(:simulated_yield, Map.fetch!(day_yields, refinery.id))
        |> Map.put(:max_utilization_ratio, plant_ratio(pace, refinery.id))
      end)

    {:ok, problem} =
      Problem.build(%{
        month: Repository.day_key(day),
        demand_m3: adjusted_demand(ctx.overrides, demand),
        initial_inventory_m3: opening,
        refineries: refineries
      })

    Result.from_solver(problem, Solver.solve(Problem.to_solver_input(problem), ctx.solver_opts))
  end

  defp plant_ratio(pace, id) do
    case pace do
      %{^id => %{ratio: ratio}} -> ratio
      _ -> Problem.burst_utilization_ratio()
    end
  end

  defp new_pace(:open) do
    %{phase: :open, ratio: Problem.burst_utilization_ratio(), surplus: 0.0, lock_left: 0}
  end

  defp new_pace(:ramping) do
    %{phase: :ramping, ratio: Problem.min_utilization_ratio(), surplus: 0.0, lock_left: 0}
  end

  defp update_pace(pace, result) do
    Enum.reduce(result.refineries, pace, fn refinery, acc ->
      previous = Map.get(acc, refinery.id, new_pace(:open))
      Map.put(acc, refinery.id, next_pace(previous, refinery))
    end)
  end

  defp next_pace(%{phase: :ramping, ratio: ratio} = state, _refinery) do
    nxt = ratio + @ratio_step
    cap = Problem.burst_utilization_ratio()

    if nxt >= cap - 1.0e-12 do
      %{state | phase: :open, ratio: cap, surplus: 0.0}
    else
      %{state | ratio: nxt}
    end
  end

  defp next_pace(%{phase: phase} = state, refinery) when phase in [:open, :falling] do
    fut = fut_ratio(refinery)
    surplus = state.surplus + max(fut - Problem.sustainable_utilization_ratio(), 0.0)
    advance_phase(%{state | surplus: surplus}, fut)
  end

  defp next_pace(%{phase: :locked, lock_left: left} = state, _refinery) do
    left = left - 1

    if left <= 0 do
      new_pace(:open)
    else
      %{state | lock_left: left}
    end
  end

  defp advance_phase(%{phase: :open, ratio: ratio} = state, fut) do
    if fut + 1.0e-6 >= @burst_hit_ratio * Problem.burst_utilization_ratio() do
      %{state | phase: :falling, ratio: ratio - @ratio_step}
    else
      state
    end
  end

  defp advance_phase(%{phase: :falling, ratio: ratio, surplus: surplus} = state, _fut) do
    next_ratio = ratio - @ratio_step
    floor = Problem.sustainable_utilization_ratio()

    if next_ratio <= floor + 1.0e-12 do
      %{state | phase: :locked, ratio: floor, lock_left: lock_days(surplus)}
    else
      %{state | ratio: next_ratio}
    end
  end

  defp fut_ratio(%{processing_capacity_m3: kp}) when kp <= 0.0, do: 0.0
  defp fut_ratio(refinery), do: refinery.petroleum_processed_m3 / refinery.processing_capacity_m3

  defp lock_days(surplus) do
    surplus
    |> Kernel./(@ratio_step)
    |> Float.ceil()
    |> trunc()
    |> max(1)
  end

  defp overrides(params) do
    values =
      params
      |> Map.take(Map.keys(%Overrides{}))
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()

    struct!(Overrides, values)
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
      allocated = Enum.sum(Enum.map(rows, & &1.allocated_m3))
      petroleum = Enum.sum(Enum.map(rows, & &1.petroleum_processed_m3))
      processing_capacity = Enum.sum(Enum.map(rows, & &1.processing_capacity_m3))
      yield = if petroleum > 0.0, do: allocated / petroleum, else: first.simulated_yield

      %{
        id: first.id,
        name: first.name,
        uf: first.uf,
        allocated_m3: allocated,
        petroleum_processed_m3: petroleum,
        processing_capacity_m3: processing_capacity,
        capacity_m3: Enum.sum(Enum.map(rows, & &1.capacity_m3)),
        floor_m3: Enum.sum(Enum.map(rows, & &1.floor_m3)),
        simulated_yield: yield,
        active: Enum.any?(rows, & &1.active),
        fut_pct: petroleum / processing_capacity * 100.0
      }
    end)
    |> Enum.sort_by(& &1.id)
  end

  defp summarize(periods) do
    demand_m3 = sum(periods, :demand_m3)
    production_m3 = sum(periods, :production_m3)
    served_demand_m3 = sum(periods, :served_demand_m3)
    petroleum = sum(periods, :total_petroleum_processed_m3)
    capacity = sum(periods, :total_processing_capacity_m3)

    %{
      demand_m3: demand_m3,
      production_m3: production_m3,
      served_demand_m3: served_demand_m3,
      deficit_m3: sum(periods, :deficit_m3),
      total_petroleum_processed_m3: petroleum,
      total_processing_capacity_m3: capacity,
      balance_m3: production_m3 - demand_m3,
      total_fut_pct: petroleum / capacity * 100.0,
      starting_inventory_m3: List.first(periods).starting_inventory_m3,
      ending_inventory_m3: List.last(periods).ending_inventory_m3,
      coverage: served_demand_m3 / demand_m3
    }
  end

  defp sum(periods, field), do: Enum.sum(Enum.map(periods, &Map.fetch!(&1, field)))
end
