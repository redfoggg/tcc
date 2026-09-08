defmodule GasolineSimulator.Models.Result do
  alias GasolineSimulator.Models.Problem

  defstruct [
    :status,
    :month,
    :balance_m3,
    :total_fut_pct,
    :total_petroleum_processed_m3,
    :total_processing_capacity_m3,
    :demand_m3,
    :starting_inventory_m3,
    :ending_inventory_m3,
    :production_m3,
    :served_demand_m3,
    :deficit_m3,
    :coverage,
    :reason,
    refineries: []
  ]

  @type t :: %__MODULE__{
          status: atom() | nil,
          month: String.t() | nil,
          balance_m3: float() | nil,
          total_fut_pct: float() | nil,
          total_petroleum_processed_m3: float() | nil,
          total_processing_capacity_m3: float() | nil,
          demand_m3: float() | nil,
          starting_inventory_m3: float() | nil,
          ending_inventory_m3: float() | nil,
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
    total_petroleum_processed_m3 = Enum.sum(Enum.map(refineries, & &1.petroleum_processed_m3))
    total_processing_capacity_m3 = Enum.sum(Enum.map(refineries, & &1.processing_capacity_m3))

    %__MODULE__{
      status: :ok,
      month: problem.month,
      balance_m3: native_result.production - native_result.demand,
      total_fut_pct: total_fut_pct(total_petroleum_processed_m3, total_processing_capacity_m3),
      total_petroleum_processed_m3: total_petroleum_processed_m3,
      total_processing_capacity_m3: total_processing_capacity_m3,
      demand_m3: native_result.demand,
      starting_inventory_m3: native_result.starting_inventory,
      ending_inventory_m3: native_result.ending_inventory,
      production_m3: native_result.production,
      served_demand_m3: native_result.served_demand,
      deficit_m3: native_result.deficit,
      coverage: native_result.coverage,
      refineries: refineries
    }
  end

  def from_solver(%Problem{} = problem, {:error, {kind, reason}}) do
    %__MODULE__{
      status: kind,
      month: problem.month,
      reason: reason,
      demand_m3: problem.demand_m3,
      starting_inventory_m3: problem.initial_inventory_m3
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
        :simulated_yield_provenance,
        :capacity_m3,
        :processing_capacity_m3,
        :floor_m3,
        :floor_provenance
      ])
      |> Map.merge(Map.take(facility, [:active, :utilization, :binding_capacity]))
      |> Map.put(:allocated_m3, facility.allocated)
      |> Map.put(:petroleum_processed_m3, facility.allocated / refinery.simulated_yield)
      |> then(fn refinery_result ->
        Map.put(
          refinery_result,
          :fut_pct,
          total_fut_pct(refinery_result.petroleum_processed_m3, refinery.processing_capacity_m3)
        )
      end)
    end)
  end

  defp total_fut_pct(_processed, capacity) when capacity <= 0.0, do: 0.0
  defp total_fut_pct(processed, capacity), do: processed / capacity * 100.0
end
