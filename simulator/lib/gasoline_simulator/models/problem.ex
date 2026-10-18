defmodule GasolineSimulator.Models.Problem do
  alias GasolineSimulator.Data.Regions
  alias GasolineSimulator.Models.Refinery

  @enforce_keys [:month, :demand_m3, :landed_m3, :planning_yield]
  defstruct [
    :month,
    :demand_m3,
    :landed_m3,
    :planning_yield,
    :carried_deficit_m3,
    :stock_by_region,
    :landed_by_region,
    refineries: []
  ]

  @type t :: %__MODULE__{
          month: String.t(),
          demand_m3: float(),
          landed_m3: float(),
          planning_yield: float(),
          carried_deficit_m3: float(),
          stock_by_region: map(),
          landed_by_region: map(),
          refineries: [Refinery.t()]
        }

  @spec build(map()) :: t()
  def build(attrs) do
    fields = Map.keys(Refinery.__struct__())

    refineries =
      Enum.map(attrs.refineries, fn refinery ->
        refinery
        |> apply_petroleum_limit()
        |> apply_min_utilization()
        |> clamp_floor()
        |> Map.take(fields)
        |> then(&struct!(Refinery, &1))
      end)

    struct!(__MODULE__, %{
      month: attrs.month,
      demand_m3: attrs.demand_m3,
      landed_m3: attrs.landed_m3,
      planning_yield: attrs.planning_yield,
      carried_deficit_m3: attrs.carried_deficit_m3,
      stock_by_region: attrs.stock_by_region,
      landed_by_region: attrs.landed_by_region,
      refineries: refineries
    })
  end

  @spec to_solver_input(t()) :: map()
  def to_solver_input(%__MODULE__{} = problem) do
    scale = problem.planning_yield

    regions =
      Enum.map(Regions.ids(), fn region ->
        stock = Map.get(problem.stock_by_region, region, 0.0)

        %{
          id: Atom.to_string(region),
          demand: Regions.demand(problem.demand_m3, region) / scale,
          landed: (Map.get(problem.landed_by_region, region, 0.0) + stock) / scale
        }
      end)

    stock = problem.stock_by_region |> Map.values() |> Enum.sum()
    refining = max(problem.demand_m3 + problem.carried_deficit_m3 - stock, 0.0)

    %{
      demand: refining / scale,
      landed: problem.landed_m3 / scale,
      regions: regions,
      facilities: Enum.map(problem.refineries, &to_facility/1)
    }
  end

  @burst_utilization_ratio 1.0
  @sustainable_utilization_ratio 0.94
  @min_utilization_ratio 0.40

  def burst_utilization_ratio, do: @burst_utilization_ratio
  def sustainable_utilization_ratio, do: @sustainable_utilization_ratio
  def min_utilization_ratio, do: @min_utilization_ratio

  defp apply_petroleum_limit(refinery) do
    Map.put(refinery, :capacity_m3, campaign_petroleum(refinery, refinery.max_utilization_ratio))
  end

  defp apply_min_utilization(refinery) do
    Map.put(refinery, :floor_m3, campaign_petroleum(refinery, refinery.min_utilization_ratio))
  end

  defp campaign_petroleum(refinery, utilization) do
    max(utilization * refinery.processing_capacity_m3 - refinery.other_charges_m3, 0.0)
  end

  defp clamp_floor(refinery),
    do: Map.update!(refinery, :floor_m3, &min(&1, refinery.capacity_m3))

  defp to_facility(%Refinery{} = refinery) do
    %{
      id: refinery.id,
      region: Atom.to_string(Regions.of_plant(refinery.id)),
      capacity: refinery.capacity_m3,
      floor: refinery.floor_m3
    }
  end
end
