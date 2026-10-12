defmodule GasolineSimulator.Models.Overrides do
  defstruct demand_adjustment_pct: 0.0

  @type t :: %__MODULE__{
          demand_adjustment_pct: float()
        }
end
