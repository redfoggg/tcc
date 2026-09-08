defmodule GasolineSimulator.Problem do
  defmodule Refinery do
    @enforce_keys [:id, :name, :uf, :capacity_m3, :floor_m3, :reference_yield]
    defstruct [
      :id,
      :name,
      :uf,
      :reference_yield,
      :reference_yield_provenance,
      :capacity_m3,
      :processing_capacity_m3,
      :floor_m3,
      :floor_provenance
    ]
  end

  @enforce_keys [:month, :demand_m3, :initial_inventory_m3]
  defstruct [
    :month,
    :demand_m3,
    :demand_provenance,
    :initial_inventory_m3,
    refineries: []
  ]

  @spec build(map()) :: {:ok, %__MODULE__{}} | {:error, String.t()}
  def build(attrs) do
    fields = Map.keys(Refinery.__struct__())

    refineries =
      Enum.map(Map.get(attrs, :refineries, []), &struct!(Refinery, Map.take(&1, fields)))

    {:ok, struct!(__MODULE__, Map.put(attrs, :refineries, refineries))}
  end

  @spec to_solver_input(%__MODULE__{}) :: map()
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
      reference_yield: refinery.reference_yield,
      capacity: refinery.capacity_m3,
      floor: refinery.floor_m3
    }
  end
end
