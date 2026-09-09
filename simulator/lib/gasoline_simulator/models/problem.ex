defmodule GasolineSimulator.Models.Problem do
  alias GasolineSimulator.Models.Refinery

  @enforce_keys [:month, :demand_m3, :initial_inventory_m3, :max_petroleum_m3]
  defstruct [
    :month,
    :demand_m3,
    :initial_inventory_m3,
    :max_petroleum_m3,
    refineries: []
  ]

  @type t :: %__MODULE__{
          month: String.t(),
          demand_m3: float(),
          initial_inventory_m3: float(),
          max_petroleum_m3: float(),
          refineries: [Refinery.t()]
        }

  @spec build(map()) :: {:ok, t()}
  def build(attrs) do
    fields = Map.keys(Refinery.__struct__())

    refineries =
      attrs
      |> Map.get(:refineries, [])
      |> Enum.map(&apply_petroleum_limit/1)
      |> Enum.map(&apply_min_utilization/1)
      |> Enum.map(&clamp_floor/1)
      |> Enum.map(&struct!(Refinery, Map.take(&1, fields)))

    {:ok, struct!(__MODULE__, Map.put(attrs, :refineries, refineries))}
  end

  @spec to_solver_input(t()) :: map()
  def to_solver_input(%__MODULE__{} = problem) do
    %{
      demand: problem.demand_m3,
      initial_inventory: problem.initial_inventory_m3,
      max_petroleum: problem.max_petroleum_m3,
      facilities: Enum.map(problem.refineries, &to_facility/1)
    }
  end

  @min_utilization_ratio 0.40

  defp apply_petroleum_limit(refinery) do
    gasoline_from_petroleum = refinery.simulated_yield * refinery.processing_capacity_m3
    Map.update!(refinery, :capacity_m3, &min(&1, gasoline_from_petroleum))
  end

  defp apply_min_utilization(refinery) do
    min_gasoline =
      @min_utilization_ratio * refinery.simulated_yield * refinery.processing_capacity_m3

    Map.put(refinery, :floor_m3, min_gasoline)
  end

  defp clamp_floor(refinery),
    do: Map.update!(refinery, :floor_m3, &min(&1, refinery.capacity_m3))

  defp to_facility(%Refinery{} = refinery) do
    %{
      id: refinery.id,
      simulated_yield: refinery.simulated_yield,
      capacity: refinery.capacity_m3,
      floor: refinery.floor_m3
    }
  end
end
