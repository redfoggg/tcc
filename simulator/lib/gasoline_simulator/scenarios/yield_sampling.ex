defmodule GasolineSimulator.Scenarios.YieldSampling do
  @spec draw(%{(1..12) => [map()]}) :: %{(1..12) => %{String.t() => float()}}
  def draw(refineries_by_period) do
    Map.new(refineries_by_period, fn {period, refineries} ->
      {period, Map.new(refineries, &{&1.id, sample(&1)})}
    end)
  end

  @spec bound(map(), :min | :max) :: map()
  def bound(refineries_by_period, extreme) do
    Map.new(refineries_by_period, fn {period, refineries} ->
      {period, Map.new(refineries, &{&1.id, extreme_yield(&1, extreme)})}
    end)
  end

  @spec campaign(map()) :: map()
  def campaign(refineries_by_period) do
    chosen =
      refineries_by_period
      |> Map.values()
      |> hd()
      |> Map.new(&{&1.id, sample(&1)})

    Map.new(refineries_by_period, fn {period, refineries} ->
      {period, Map.new(refineries, &{&1.id, Map.fetch!(chosen, &1.id)})}
    end)
  end

  defp sample(refinery) do
    drawn =
      case refinery.observed_monthly_yields do
        [] -> 0.0
        yields -> Enum.random(yields)
      end

    if drawn > 0.0, do: drawn, else: refinery.national_average_yield
  end

  defp extreme_yield(refinery, extreme) do
    positives = Enum.filter(refinery.observed_monthly_yields, &(&1 > 0.0))

    case positives do
      [] -> refinery.national_average_yield
      _ when extreme == :min -> Enum.min(positives)
      _ -> Enum.max(positives)
    end
  end
end
