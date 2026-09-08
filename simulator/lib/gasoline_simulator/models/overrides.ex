defmodule GasolineSimulator.Models.Overrides do
  defstruct initial_inventory_m3: 0.0,
            demand_adjustment_pct: 0.0,
            floor_overrides: %{}

  @type t :: %__MODULE__{
          initial_inventory_m3: float(),
          demand_adjustment_pct: float(),
          floor_overrides: %{String.t() => float()}
        }

  @spec build(map()) :: {:ok, t()}
  def build(attrs) do
    values =
      attrs
      |> Map.take(Map.keys(%__MODULE__{}))
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()

    {:ok, struct!(__MODULE__, values)}
  end

  @spec apply_demand(t(), float()) :: float()
  def apply_demand(%__MODULE__{demand_adjustment_pct: pct}, demand_m3),
    do: demand_m3 * (1.0 + pct / 100.0)

  @spec floor_override(t(), String.t()) :: float() | nil
  def floor_override(%__MODULE__{floor_overrides: floor_overrides}, refinery_id),
    do: Map.get(floor_overrides, refinery_id)
end
