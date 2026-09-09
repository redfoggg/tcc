defmodule GasolineSimulator.Scenarios.Runner do
  alias GasolineSimulator.Data.Repository
  alias GasolineSimulator.Models.Overrides
  alias GasolineSimulator.Models.Problem
  alias GasolineSimulator.Models.Result
  alias GasolineSimulator.Scenarios.YieldSampling
  alias GasolineSimulator.Solver

  @annual_fut_ratio 0.90

  @spec run(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def run(params \\ %{}, opts \\ []) do
    overrides = overrides(params)
    year_data = Repository.load_year(Keyword.take(opts, [:data_dir]))
    simulated_yields = YieldSampling.draw(year_data.refineries_by_day)
    solver_opts = Keyword.take(opts, [:timeout, :task_supervisor])

    with {:ok, days} <- run_days(overrides, year_data, simulated_yields, solver_opts) do
      months = months_from_days(days)
      {:ok, %{days: days, months: months, annual: summarize(days)}}
    end
  end

  defp run_days(overrides, year_data, simulated_yields, solver_opts) do
    petroleum_budget = annual_petroleum_budget(year_data)
    oil_need_by_day = oil_need_by_day(year_data, overrides, simulated_yields)
    annual_oil_need = oil_need_by_day |> Map.values() |> Enum.sum()

    Repository.days()
    |> Enum.reduce_while(
      {[], overrides.initial_inventory_m3, petroleum_budget},
      fn day, {acc, opening, remaining} ->
        cap =
          day_petroleum_cap(
            day,
            remaining,
            petroleum_budget,
            annual_oil_need,
            oil_need_by_day,
            year_data
          )

        result = solve_day(day, opening, cap, overrides, year_data, simulated_yields, solver_opts)

        if result.status == :ok do
          leftover = max(remaining - result.total_petroleum_processed_m3, 0.0)
          {:cont, {[result | acc], result.ending_inventory_m3, leftover}}
        else
          {:halt, {:error, result}}
        end
      end
    )
    |> case do
      {:error, failed} -> {:error, failed}
      {acc, _inventory, _remaining} -> {:ok, Enum.reverse(acc)}
    end
  end

  defp solve_day(day, opening, max_petroleum, overrides, year_data, simulated_yields, solver_opts) do
    day_yields = Map.fetch!(simulated_yields, day)
    demand = Map.fetch!(year_data.demand_by_day, day).demand_m3

    {:ok, problem} =
      Problem.build(%{
        month: Repository.day_key(day),
        demand_m3: adjusted_demand(overrides, demand),
        initial_inventory_m3: opening,
        max_petroleum_m3: max_petroleum,
        refineries:
          Enum.map(Map.fetch!(year_data.refineries_by_day, day), fn refinery ->
            Map.put(refinery, :simulated_yield, Map.fetch!(day_yields, refinery.id))
          end)
      })

    Result.from_solver(problem, Solver.solve(Problem.to_solver_input(problem), solver_opts))
  end

  defp annual_petroleum_budget(year_data) do
    year_data.refineries_by_day
    |> Map.values()
    |> List.flatten()
    |> processing_capacity()
    |> Kernel.*(@annual_fut_ratio)
  end

  defp day_petroleum_cap(
         day,
         remaining,
         petroleum_budget,
         annual_oil_need,
         oil_need_by_day,
         year_data
       ) do
    day_capacity = processing_capacity(Map.fetch!(year_data.refineries_by_day, day))

    future_need =
      oil_need_by_day
      |> Enum.filter(fn {later, _need} -> Date.compare(later, day) == :gt end)
      |> Enum.map(fn {_later, need} -> need end)
      |> Enum.sum()

    reserved = petroleum_budget * future_need / annual_oil_need
    min(day_capacity, max(remaining - reserved, 0.0))
  end

  defp oil_need_by_day(year_data, overrides, simulated_yields) do
    Map.new(year_data.demand_by_day, fn {day, entry} ->
      demand = adjusted_demand(overrides, entry.demand_m3)
      {day, demand / capacity_weighted_yield(year_data, day, simulated_yields)}
    end)
  end

  defp capacity_weighted_yield(year_data, day, simulated_yields) do
    refineries = Map.fetch!(year_data.refineries_by_day, day)
    day_yields = Map.fetch!(simulated_yields, day)
    capacity = processing_capacity(refineries)

    Enum.sum(
      Enum.map(refineries, fn refinery ->
        Map.fetch!(day_yields, refinery.id) * refinery.processing_capacity_m3
      end)
    ) / capacity
  end

  defp processing_capacity(refineries),
    do: Enum.sum(Enum.map(refineries, & &1.processing_capacity_m3))

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
