defmodule GasolineSimulator.Models.Refinery do
  @enforce_keys [:id, :name, :uf, :capacity_m3, :floor_m3, :simulated_yield]
  defstruct [
    :id,
    :name,
    :uf,
    :simulated_yield,
    :simulated_yield_provenance,
    :capacity_m3,
    :processing_capacity_m3,
    :floor_m3,
    :floor_provenance
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          uf: String.t(),
          simulated_yield: float(),
          simulated_yield_provenance: String.t() | nil,
          capacity_m3: float(),
          processing_capacity_m3: float() | nil,
          floor_m3: float(),
          floor_provenance: String.t() | nil
        }
end
