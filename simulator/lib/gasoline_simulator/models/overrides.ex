defmodule GasolineSimulator.Models.Overrides do
  @min_transit_days 1

  defstruct demand_adjustment_pct: 0.0,
            transit_days: @min_transit_days

  @type t :: %__MODULE__{
          demand_adjustment_pct: float(),
          transit_days: pos_integer()
        }

  def min_transit_days, do: @min_transit_days

  def transit_days(days) when is_integer(days) and days >= @min_transit_days, do: days
  def transit_days(_days), do: @min_transit_days
end
