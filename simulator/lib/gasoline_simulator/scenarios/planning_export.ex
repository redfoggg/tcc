defmodule GasolineSimulator.Scenarios.PlanningExport do
  alias GasolineSimulator.Models.Plan
  alias GasolineSimulator.Models.Result

  @schema_version "5.0.0"
  @mechanics_fields [
    :starting_inventory_m3,
    :ending_inventory_m3,
    :served_demand_m3,
    :deficit_m3,
    :coverage,
    :total_petroleum_processed_m3,
    :total_processing_capacity_m3
  ]
  @refinery_fields [
    :id,
    :name,
    :uf,
    :allocated_m3,
    :active,
    :utilization,
    :binding_capacity,
    :simulated_yield,
    :simulated_yield_provenance,
    :capacity_m3,
    :processing_capacity_m3,
    :petroleum_processed_m3,
    :fut_pct,
    :floor_m3,
    :floor_provenance
  ]

  @spec build(map(), Plan.t(), keyword()) :: map()
  def build(historical, %Plan{} = planned, opts \\ []) do
    %{
      schema_version: @schema_version,
      generated_at: Keyword.get(opts, :generated_at, DateTime.utc_now()),
      historical: comparison_entry(historical),
      planned: planned_entry(planned)
    }
  end

  defp planned_entry(%Plan{} = planned) do
    outcome = outcome(planned.result)

    %{
      id: planned.id,
      status: planned.status,
      controls: planned.params,
      started_at: planned.started_at,
      completed_at: planned.completed_at,
      provenance: %{
        total_fut_pct:
          "Ratio of the sum of planned utilized petroleum throughput to the sum of raw petroleum processing capacity across the fixed refinery scope. Annual total is capped at 90%. Each month's petroleum cap is the leftover annual budget minus the share owed to later months, weighted by demand over that month's capacity-weighted simulated yield"
      },
      error: outcome.error,
      annual: outcome.annual,
      months: outcome.months,
      mechanics: outcome.mechanics
    }
  end

  defp outcome(%{months: months, annual: annual}) do
    %{
      error: nil,
      annual: planned_annual(annual),
      months: Enum.map(months, &planned_month/1),
      mechanics: %{
        annual: Map.drop(annual, [:production_m3, :demand_m3, :balance_m3, :total_fut_pct]),
        months: Enum.map(months, &mechanics_month/1)
      }
    }
  end

  defp outcome(%Result{} = failed_month) do
    error_outcome(failed_month.status, "month #{failed_month.month}: #{failed_month.reason}")
  end

  defp outcome(nil), do: base_outcome()
  defp outcome(reason) when is_binary(reason), do: error_outcome(:planning_error, reason)
  defp outcome(other), do: error_outcome(:runner_error, other)

  defp error_outcome(kind, reason) do
    Map.put(base_outcome(), :error, %{kind: kind, reason: error_reason(reason)})
  end

  defp base_outcome, do: %{error: nil, annual: nil, months: [], mechanics: nil}

  defp comparison_entry(historical) do
    %{
      annual: comparison_annual(historical.annual),
      months: Enum.map(historical.months, &comparison_month/1)
    }
  end

  defp comparison_annual(annual),
    do:
      Map.take(annual, [
        :production_supplied_m3,
        :demand_target_m3,
        :balance_m3,
        :total_fut_pct
      ])

  defp comparison_month(month), do: Map.put(comparison_annual(month), :month, month.month)

  defp planned_annual(annual) do
    %{
      production_supplied_m3: annual.production_m3,
      demand_target_m3: annual.demand_m3,
      balance_m3: annual.balance_m3,
      total_fut_pct: annual.total_fut_pct
    }
  end

  defp planned_month(%Result{} = result),
    do: Map.put(planned_annual(result), :month, result.month)

  defp mechanics_month(%Result{} = result) do
    result
    |> Map.take([:month, :status] ++ @mechanics_fields)
    |> Map.put(:refineries, Enum.map(result.refineries, &Map.take(&1, @refinery_fields)))
  end

  defp error_reason(reason) when is_binary(reason), do: reason
  defp error_reason(reason), do: inspect(reason)
end
