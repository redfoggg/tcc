defmodule GasolineSimulator.Models.Overrides do
  defstruct demand_adjustment_pct: 0.0,
            demand_by_month: %{}

  @type t :: %__MODULE__{
          demand_adjustment_pct: float(),
          demand_by_month: %{optional(pos_integer()) => number()}
        }
end
