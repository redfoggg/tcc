defmodule GasolineSimulator.Models.Result do
  alias GasolineSimulator.Data.Regions
  alias GasolineSimulator.Models.Problem

  defstruct [
    :status,
    :month,
    :balance_m3,
    :total_fut_pct,
    :total_petroleum_processed_m3,
    :total_other_charges_m3,
    :total_processing_capacity_m3,
    :demand_m3,
    :landed_m3,
    :excess_m3,
    :production_m3,
    :served_demand_m3,
    :deficit_m3,
    :coverage,
    :reason,
    regions: [],
    refineries: [],
    stock_by_id: %{}
  ]

  @type t :: %__MODULE__{
          status: atom() | nil,
          month: String.t() | nil,
          balance_m3: float() | nil,
          total_fut_pct: float() | nil,
          total_petroleum_processed_m3: float() | nil,
          total_other_charges_m3: float() | nil,
          total_processing_capacity_m3: float() | nil,
          demand_m3: float() | nil,
          landed_m3: float() | nil,
          excess_m3: float() | nil,
          production_m3: float() | nil,
          served_demand_m3: float() | nil,
          deficit_m3: float() | nil,
          coverage: float() | nil,
          reason: String.t() | nil,
          refineries: [map()]
        }

  @spec from_solver(Problem.t(), {:ok, map()} | {:error, {atom(), String.t()}}) :: t()
  def from_solver(%Problem{} = problem, {:ok, native_result}) do
    refineries = merge_refineries(problem, native_result.facilities)
    production_m3 = Enum.sum_by(refineries, & &1.allocated_m3)
    covered_m3 = production_m3 + problem.landed_m3
    deficit_m3 = max(problem.demand_m3 - covered_m3, 0.0)
    excess_m3 = max(covered_m3 - problem.demand_m3, 0.0)
    served_demand_m3 = problem.demand_m3 - deficit_m3
    total_petroleum_processed_m3 = Enum.sum_by(refineries, & &1.petroleum_processed_m3)
    total_other_charges_m3 = Enum.sum_by(refineries, & &1.other_charges_m3)
    total_processing_capacity_m3 = Enum.sum_by(refineries, & &1.processing_capacity_m3)

    %__MODULE__{
      status: :ok,
      month: problem.month,
      balance_m3: production_m3 - problem.demand_m3,
      total_fut_pct:
        total_fut_pct(
          total_petroleum_processed_m3 + total_other_charges_m3,
          total_processing_capacity_m3
        ),
      total_petroleum_processed_m3: total_petroleum_processed_m3,
      total_other_charges_m3: total_other_charges_m3,
      total_processing_capacity_m3: total_processing_capacity_m3,
      demand_m3: problem.demand_m3,
      landed_m3: problem.landed_m3,
      excess_m3: excess_m3,
      production_m3: production_m3,
      served_demand_m3: served_demand_m3,
      deficit_m3: deficit_m3,
      coverage: coverage(served_demand_m3, problem.demand_m3),
      refineries: refineries
    }
  end

  def from_solver(%Problem{} = problem, {:error, {kind, reason}}) do
    %__MODULE__{
      status: kind,
      month: problem.month,
      reason: reason,
      demand_m3: problem.demand_m3,
      landed_m3: problem.landed_m3
    }
  end

  def cover_regions(result, shipped_by_region, landed_by_region, opening_by_region) do
    regions =
      Enum.map(Regions.ids(), fn region ->
        produced =
          result.refineries
          |> Enum.filter(&(Regions.of_plant(&1.id) == region))
          |> Enum.sum_by(& &1.allocated_m3)

        demand = Regions.demand(result.demand_m3, region)
        opening = Map.get(opening_by_region, region, 0.0)
        arrived = Map.get(landed_by_region, region, 0.0)
        left = Map.get(shipped_by_region, region, 0.0)
        fresh = produced + arrived - left
        deficit = max(demand - opening - fresh, 0.0)
        closing = max(opening + fresh - demand, 0.0)

        %{
          id: region,
          demand_m3: demand,
          produced_m3: produced,
          supply_m3: fresh,
          served_m3: demand - deficit,
          deficit_m3: deficit,
          excess_m3: max(closing - opening, 0.0)
        }
      end)

    deficit_m3 = Enum.sum_by(regions, & &1.deficit_m3)
    excess_m3 = Enum.sum_by(regions, & &1.excess_m3)
    opening = opening_by_region |> Map.values() |> Enum.sum()
    shipped = shipped_by_region |> Map.values() |> Enum.sum()
    available_m3 = result.production_m3 + opening + result.landed_m3 - shipped
    served_demand_m3 = result.demand_m3 - deficit_m3

    %{
      result
      | balance_m3: available_m3 - result.demand_m3,
        excess_m3: excess_m3,
        served_demand_m3: served_demand_m3,
        deficit_m3: deficit_m3,
        coverage: coverage(served_demand_m3, result.demand_m3),
        regions: regions
    }
  end

  def withhold_shipments(%__MODULE__{} = result, shipped) when shipped <= 0.0, do: result

  def withhold_shipments(%__MODULE__{} = result, shipped) do
    available_m3 = result.production_m3 - shipped + result.landed_m3
    deficit_m3 = max(result.demand_m3 - available_m3, 0.0)
    excess_m3 = max(available_m3 - result.demand_m3, 0.0)
    served_demand_m3 = result.demand_m3 - deficit_m3

    %{
      result
      | balance_m3: available_m3 - result.demand_m3,
        excess_m3: excess_m3,
        served_demand_m3: served_demand_m3,
        deficit_m3: deficit_m3,
        coverage: coverage(served_demand_m3, result.demand_m3)
    }
  end

  defp merge_refineries(problem, facility_results) do
    facility_by_id = Map.new(facility_results, &{&1.id, &1})

    Enum.map(problem.refineries, fn refinery ->
      facility = Map.fetch!(facility_by_id, refinery.id)

      refinery
      |> Map.take([
        :id,
        :name,
        :uf,
        :simulated_yield,
        :capacity_m3,
        :processing_capacity_m3,
        :other_charges_m3,
        :floor_m3
      ])
      |> Map.merge(Map.take(facility, [:active]))
      |> Map.put(:petroleum_processed_m3, facility.allocated)
      |> Map.put(:planned_m3, facility.allocated * problem.planning_yield)
      |> Map.put(:allocated_m3, facility.allocated * refinery.simulated_yield)
      |> then(fn refinery_result ->
        Map.put(
          refinery_result,
          :fut_pct,
          total_fut_pct(
            refinery_result.petroleum_processed_m3 + refinery_result.other_charges_m3,
            refinery.processing_capacity_m3
          )
        )
      end)
    end)
  end

  defp coverage(_served, demand) when demand <= 0.0, do: 0.0
  defp coverage(served, demand), do: served / demand

  defp total_fut_pct(processed, capacity), do: processed / capacity * 100.0
end
