defmodule GasolineSimulator.Scenarios.YieldSampling do
  @spec draw(%{(1..12) => [map()]}) :: %{(1..12) => %{String.t() => float()}}
  def draw(refineries_by_period) do
    Map.new(refineries_by_period, fn {period, refineries} ->
      {period, Map.new(refineries, &{&1.id, sample(&1)})}
    end)
  end

  defp sample(refinery) do
    yields = Map.get(refinery, :observed_monthly_yields, [])
    national_average = Map.get(refinery, :national_average_yield, 0.0)

    drawn =
      case yields do
        [] -> 0.0
        _ -> Enum.random(yields)
      end

    if drawn > 0.0, do: drawn, else: national_average
  end
end
