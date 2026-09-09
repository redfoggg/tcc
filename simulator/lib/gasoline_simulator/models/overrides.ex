defmodule GasolineSimulator.Models.Overrides do
  defstruct initial_inventory_m3: 0.0,
            demand_adjustment_pct: 0.0

  @type t :: %__MODULE__{
          initial_inventory_m3: float(),
          demand_adjustment_pct: float()
        }
end
