defmodule GasolineSimulator.Scenarios.Runner do
  alias GasolineSimulator.Data.Repository
  alias GasolineSimulator.Models.Overrides
  alias GasolineSimulator.Models.Problem
  alias GasolineSimulator.Models.Result
  alias GasolineSimulator.Scenarios.YieldSampling
  alias GasolineSimulator.Solver

  @annual_fut_ratio 0.90
  @min_utilization_ratio 0.40

  @annual_fields [
    demand_m3: :demand_m3,
    production_m3: :production_m3,
    served_demand_m3: :served_demand_m3,
    deficit_m3: :deficit_m3,
    total_petroleum_processed_m3: :total_petroleum_processed_m3,
    total_processing_capacity_m3: :total_processing_capacity_m3
  ]

  @spec run(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def run(params \\ %{}, opts \\ []) do
    with {:ok, overrides} <- Overrides.build(params) do
      repository_opts = Keyword.take(opts, [:data_dir])
      solver_opts = Keyword.take(opts, [:timeout, :task_supervisor])

      year_data = Repository.load_year(repository_opts)
      simulated_yields = YieldSampling.draw(year_data.refineries_by_month)

      with {:ok, months} <-
             run_months(Repository.months(), overrides, year_data, simulated_yields, solver_opts) do
        {:ok, %{months: months, annual: summarize(months)}}
      end
    end
  end

  defp run_months(months, overrides, year_data, simulated_yields, solver_opts) do
    petroleum_budget = annual_petroleum_budget(year_data)
    oil_need_by_month = oil_need_by_month(year_data, overrides, simulated_yields)
    annual_oil_need = oil_need_by_month |> Map.values() |> Enum.sum()

    months
    |> Enum.reduce_while(
      {[], overrides.initial_inventory_m3, petroleum_budget},
      fn month, {acc, opening, remaining} ->
        result =
          solve_month(
            month,
            opening,
            month_petroleum_cap(
              month,
              remaining,
              petroleum_budget,
              annual_oil_need,
              oil_need_by_month,
              year_data
            ),
            overrides,
            year_data,
            simulated_yields,
            solver_opts
          )

        case result.status do
          :ok ->
            leftover = max(remaining - result.total_petroleum_processed_m3, 0.0)
            {:cont, {[result | acc], result.ending_inventory_m3, leftover}}

          _ ->
            {:halt, {:error, result}}
        end
      end
    )
    |> finish()
  end

  defp finish({:error, failed_result}), do: {:error, failed_result}
  defp finish({acc, _final_inventory, _remaining_petroleum}), do: {:ok, Enum.reverse(acc)}

  defp solve_month(
         month,
         opening_inventory,
         remaining_petroleum,
         overrides,
         year_data,
         simulated_yields,
         solver_opts
       ) do
    attrs =
      build_month_attrs(
        month,
        opening_inventory,
        remaining_petroleum,
        overrides,
        year_data,
        simulated_yields
      )

    {:ok, problem} = Problem.build(attrs)

    Result.from_solver(problem, Solver.solve(Problem.to_solver_input(problem), solver_opts))
  end

  defp build_month_attrs(
         month,
         opening_inventory,
         remaining_petroleum,
         overrides,
         year_data,
         simulated_yields
       ) do
    demand_entry = Map.fetch!(year_data.demand_by_month, month)
    adjusted_demand = Overrides.apply_demand(overrides, demand_entry.demand_m3)
    month_yields = Map.fetch!(simulated_yields, month)
    month_refineries = Map.fetch!(year_data.refineries_by_month, month)

    %{
      month: Repository.month_key(month),
      demand_m3: adjusted_demand,
      demand_provenance: demand_provenance(overrides, demand_entry.demand_provenance),
      initial_inventory_m3: opening_inventory,
      max_petroleum_m3: remaining_petroleum,
      refineries: Enum.map(month_refineries, &build_refinery_attrs(&1, month_yields))
    }
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
    month_capacity = month_processing_capacity(year_data, month)
    reserved = reserved_petroleum(month, petroleum_budget, annual_oil_need, oil_need_by_month)
    min(month_capacity, max(remaining - reserved, 0.0))
  end

  defp reserved_petroleum(_month, _petroleum_budget, annual_oil_need, _oil_need_by_month)
       when annual_oil_need <= 0.0,
       do: 0.0

  defp reserved_petroleum(month, petroleum_budget, annual_oil_need, oil_need_by_month) do
    future_need =
      oil_need_by_month
      |> Enum.filter(fn {later, _need} -> later > month end)
      |> Enum.map(fn {_later, need} -> need end)
      |> Enum.sum()

    petroleum_budget * future_need / annual_oil_need
  end

  defp oil_need_by_month(year_data, overrides, simulated_yields) do
    Map.new(year_data.demand_by_month, fn {month, entry} ->
      demand = Overrides.apply_demand(overrides, entry.demand_m3)
      mean_yield = capacity_weighted_yield(year_data, month, simulated_yields)
      need = if mean_yield > 0.0, do: demand / mean_yield, else: 0.0
      {month, need}
    end)
  end

  defp capacity_weighted_yield(year_data, month, simulated_yields) do
    refineries = Map.fetch!(year_data.refineries_by_month, month)
    month_yields = Map.fetch!(simulated_yields, month)
    capacity = processing_capacity(refineries)
    weighted_yield(refineries, month_yields, capacity)
  end

  defp weighted_yield(_refineries, _month_yields, capacity) when capacity <= 0.0, do: 0.0

  defp weighted_yield(refineries, month_yields, capacity) do
    Enum.sum(
      Enum.map(refineries, fn refinery ->
        Map.fetch!(month_yields, refinery.id) * refinery.processing_capacity_m3
      end)
    ) / capacity
  end

  defp month_processing_capacity(year_data, month),
    do: processing_capacity(Map.fetch!(year_data.refineries_by_month, month))

  defp processing_capacity(refineries),
    do: Enum.sum(Enum.map(refineries, & &1.processing_capacity_m3))

  defp demand_provenance(%Overrides{demand_adjustment_pct: pct}, base_provenance)
       when pct == 0.0,
       do: base_provenance

  defp demand_provenance(%Overrides{demand_adjustment_pct: pct}, base_provenance),
    do: "#{base_provenance}, planned demand adjustment #{pct}%"

  defp build_refinery_attrs(refinery, month_yields) do
    refinery
    |> Map.merge(%{
      simulated_yield: Map.fetch!(month_yields, refinery.id),
      simulated_yield_provenance: YieldSampling.provenance()
    })
    |> apply_petroleum_limit()
    |> apply_min_utilization()
    |> clamp_floor()
  end

  defp apply_petroleum_limit(refinery) do
    gasoline_from_petroleum = refinery.simulated_yield * refinery.processing_capacity_m3
    Map.update!(refinery, :capacity_m3, &min(&1, gasoline_from_petroleum))
  end

  defp apply_min_utilization(refinery) do
    min_gasoline =
      @min_utilization_ratio * refinery.simulated_yield * refinery.processing_capacity_m3

    Map.merge(refinery, %{
      floor_m3: min_gasoline,
      floor_provenance: "minimum_utilization_0.40"
    })
  end

  defp clamp_floor(refinery),
    do: Map.update!(refinery, :floor_m3, &min(&1, refinery.capacity_m3))

  defp summarize(months) do
    totals =
      Map.new(@annual_fields, fn {output, input} ->
        {output, Enum.sum(Enum.map(months, &Map.fetch!(&1, input)))}
      end)

    totals
    |> Map.merge(%{
      balance_m3: totals.production_m3 - totals.demand_m3,
      total_fut_pct:
        total_fut_pct(totals.total_petroleum_processed_m3, totals.total_processing_capacity_m3),
      starting_inventory_m3: List.first(months).starting_inventory_m3,
      ending_inventory_m3: List.last(months).ending_inventory_m3,
      coverage: annual_coverage(totals.served_demand_m3, totals.demand_m3),
      active_refinery_ids: active_refinery_ids(months)
    })
  end

  defp total_fut_pct(_processed, capacity) when capacity <= 0.0, do: 0.0
  defp total_fut_pct(processed, capacity), do: processed / capacity * 100.0

  defp annual_coverage(_served, demand) when demand <= 0.0, do: 1.0
  defp annual_coverage(served, demand), do: served / demand

  defp active_refinery_ids(months) do
    months
    |> Enum.flat_map(& &1.refineries)
    |> Enum.filter(& &1.active)
    |> Enum.map(& &1.id)
    |> Enum.uniq()
    |> Enum.sort()
  end
end
