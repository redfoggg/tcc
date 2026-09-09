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
    simulated_yields = YieldSampling.draw(year_data.refineries_by_month)
    solver_opts = Keyword.take(opts, [:timeout, :task_supervisor])

    with {:ok, months} <- run_months(overrides, year_data, simulated_yields, solver_opts) do
      {:ok, %{months: months, annual: summarize(months)}}
    end
  end

  defp run_months(overrides, year_data, simulated_yields, solver_opts) do
    petroleum_budget = annual_petroleum_budget(year_data)
    oil_need_by_month = oil_need_by_month(year_data, overrides, simulated_yields)
    annual_oil_need = oil_need_by_month |> Map.values() |> Enum.sum()

    1..12
    |> Enum.reduce_while(
      {[], overrides.initial_inventory_m3, petroleum_budget},
      fn month, {acc, opening, remaining} ->
        cap =
          month_petroleum_cap(
            month,
            remaining,
            petroleum_budget,
            annual_oil_need,
            oil_need_by_month,
            year_data
          )

        result =
          solve_month(month, opening, cap, overrides, year_data, simulated_yields, solver_opts)

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

  defp solve_month(
         month,
         opening,
         max_petroleum,
         overrides,
         year_data,
         simulated_yields,
         solver_opts
       ) do
    month_yields = Map.fetch!(simulated_yields, month)
    demand = Map.fetch!(year_data.demand_by_month, month).demand_m3

    {:ok, problem} =
      Problem.build(%{
        month: Repository.month_key(month),
        demand_m3: adjusted_demand(overrides, demand),
        initial_inventory_m3: opening,
        max_petroleum_m3: max_petroleum,
        refineries:
          Enum.map(Map.fetch!(year_data.refineries_by_month, month), fn refinery ->
            Map.put(refinery, :simulated_yield, Map.fetch!(month_yields, refinery.id))
          end)
      })

    Result.from_solver(problem, Solver.solve(Problem.to_solver_input(problem), solver_opts))
  end

  defp annual_petroleum_budget(year_data) do
    year_data.refineries_by_month
    |> Map.values()
    |> List.flatten()
    |> processing_capacity()
    |> Kernel.*(@annual_fut_ratio)
  end

  defp month_petroleum_cap(
         month,
         remaining,
         petroleum_budget,
         annual_oil_need,
         oil_need_by_month,
         year_data
       ) do
    month_capacity = processing_capacity(Map.fetch!(year_data.refineries_by_month, month))

    future_need =
      oil_need_by_month
      |> Enum.filter(fn {later, _need} -> later > month end)
      |> Enum.map(fn {_later, need} -> need end)
      |> Enum.sum()

    reserved = petroleum_budget * future_need / annual_oil_need
    min(month_capacity, max(remaining - reserved, 0.0))
  end

  defp oil_need_by_month(year_data, overrides, simulated_yields) do
    Map.new(year_data.demand_by_month, fn {month, entry} ->
      demand = adjusted_demand(overrides, entry.demand_m3)
      {month, demand / capacity_weighted_yield(year_data, month, simulated_yields)}
    end)
  end

  defp capacity_weighted_yield(year_data, month, simulated_yields) do
    refineries = Map.fetch!(year_data.refineries_by_month, month)
    month_yields = Map.fetch!(simulated_yields, month)
    capacity = processing_capacity(refineries)

    Enum.sum(
      Enum.map(refineries, fn refinery ->
        Map.fetch!(month_yields, refinery.id) * refinery.processing_capacity_m3
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

  defp summarize(months) do
    demand_m3 = sum(months, :demand_m3)
    production_m3 = sum(months, :production_m3)
    served_demand_m3 = sum(months, :served_demand_m3)
    petroleum = sum(months, :total_petroleum_processed_m3)
    capacity = sum(months, :total_processing_capacity_m3)

    %{
      demand_m3: demand_m3,
      production_m3: production_m3,
      served_demand_m3: served_demand_m3,
      deficit_m3: sum(months, :deficit_m3),
      total_petroleum_processed_m3: petroleum,
      total_processing_capacity_m3: capacity,
      balance_m3: production_m3 - demand_m3,
      total_fut_pct: petroleum / capacity * 100.0,
      starting_inventory_m3: List.first(months).starting_inventory_m3,
      ending_inventory_m3: List.last(months).ending_inventory_m3,
      coverage: served_demand_m3 / demand_m3
    }
  end

  defp sum(months, field), do: Enum.sum(Enum.map(months, &Map.fetch!(&1, field)))
end
