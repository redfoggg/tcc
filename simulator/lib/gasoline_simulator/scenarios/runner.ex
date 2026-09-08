defmodule GasolineSimulator.Scenarios.Runner do
  alias GasolineSimulator.Data.Repository
  alias GasolineSimulator.Models.Overrides
  alias GasolineSimulator.Models.Problem
  alias GasolineSimulator.Models.Result
  alias GasolineSimulator.Scenarios.YieldSampling
  alias GasolineSimulator.Solver

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
    months
    |> Enum.reduce_while({[], overrides.initial_inventory_m3}, fn month, {acc, opening} ->
      result = solve_month(month, opening, overrides, year_data, simulated_yields, solver_opts)

      case result.status do
        :ok -> {:cont, {[result | acc], result.ending_inventory_m3}}
        _ -> {:halt, {:error, result}}
      end
    end)
    |> finish()
  end

  defp finish({:error, failed_result}), do: {:error, failed_result}
  defp finish({acc, _final_inventory}), do: {:ok, Enum.reverse(acc)}

  defp solve_month(month, opening_inventory, overrides, year_data, simulated_yields, solver_opts) do
    attrs = build_month_attrs(month, opening_inventory, overrides, year_data, simulated_yields)
    {:ok, problem} = Problem.build(attrs)

    Result.from_solver(problem, Solver.solve(Problem.to_solver_input(problem), solver_opts))
  end

  defp build_month_attrs(month, opening_inventory, overrides, year_data, simulated_yields) do
    demand_entry = Map.fetch!(year_data.demand_by_month, month)
    adjusted_demand = Overrides.apply_demand(overrides, demand_entry.demand_m3)
    month_yields = Map.fetch!(simulated_yields, month)

    %{
      month: Repository.month_key(month),
      demand_m3: adjusted_demand,
      demand_provenance: demand_provenance(overrides, demand_entry.demand_provenance),
      initial_inventory_m3: opening_inventory,
      refineries:
        year_data.refineries_by_month
        |> Map.fetch!(month)
        |> Enum.map(&build_refinery_attrs(&1, overrides, month_yields))
    }
  end

  defp demand_provenance(%Overrides{demand_adjustment_pct: pct}, base_provenance)
       when pct == 0.0,
       do: base_provenance

  defp demand_provenance(%Overrides{demand_adjustment_pct: pct}, base_provenance),
    do: "#{base_provenance}, planned demand adjustment #{pct}%"

  defp build_refinery_attrs(refinery, overrides, month_yields) do
    refinery
    |> Map.merge(%{
      simulated_yield: Map.fetch!(month_yields, refinery.id),
      simulated_yield_provenance: YieldSampling.provenance()
    })
    |> apply_floor_override(overrides)
    |> clamp_floor()
  end

  defp apply_floor_override(refinery, overrides) do
    case Overrides.floor_override(overrides, refinery.id) do
      nil -> refinery
      floor_m3 -> Map.merge(refinery, %{floor_m3: floor_m3, floor_provenance: "user_override"})
    end
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
