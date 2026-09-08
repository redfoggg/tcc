defmodule GasolineSimulator.Models.Problem do
  alias GasolineSimulator.Models.Refinery

  @enforce_keys [:month, :demand_m3, :initial_inventory_m3]
  defstruct [
    :month,
    :demand_m3,
    :demand_provenance,
    :initial_inventory_m3,
    refineries: []
  ]

  @type t :: %__MODULE__{
          month: String.t(),
          demand_m3: float(),
          demand_provenance: String.t() | nil,
          initial_inventory_m3: float(),
          refineries: [Refinery.t()]
        }

  @spec build(map()) :: {:ok, t()}
  def build(attrs) do
    fields = Map.keys(Refinery.__struct__())

    refineries =
      Enum.map(Map.get(attrs, :refineries, []), &struct!(Refinery, Map.take(&1, fields)))

    {:ok, struct!(__MODULE__, Map.put(attrs, :refineries, refineries))}
  end

  @spec to_solver_input(t()) :: map()
  def to_solver_input(%__MODULE__{} = problem) do
    %{
      demand: problem.demand_m3,
      initial_inventory: problem.initial_inventory_m3,
      facilities: Enum.map(problem.refineries, &to_facility/1)
    }
  end

  defp to_facility(%Refinery{} = refinery) do
    %{
      id: refinery.id,
      simulated_yield: refinery.simulated_yield,
      capacity: refinery.capacity_m3,
      floor: refinery.floor_m3
    }
  end
end
