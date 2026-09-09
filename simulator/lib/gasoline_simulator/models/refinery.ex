defmodule GasolineSimulator.Models.Refinery do
  @enforce_keys [:id, :name, :uf, :capacity_m3, :floor_m3, :simulated_yield]
  defstruct [
    :id,
    :name,
    :uf,
    :simulated_yield,
    :capacity_m3,
    :processing_capacity_m3,
    :floor_m3
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          uf: String.t(),
          simulated_yield: float(),
          capacity_m3: float(),
          processing_capacity_m3: float() | nil,
          floor_m3: float()
        }
end
