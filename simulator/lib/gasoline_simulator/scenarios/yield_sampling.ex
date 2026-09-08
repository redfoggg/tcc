defmodule GasolineSimulator.Scenarios.YieldSampling do
  @min_yield 0.20
  @max_yield 0.25

  @provenance "Simulated gasoline A yield, independently sampled per refinery-month " <>
                "from Uniform(0.20, 0.25) for this planning run"

  @spec provenance() :: String.t()
  def provenance, do: @provenance

  @spec draw(%{(1..12) => [%{id: String.t()}]}) :: %{(1..12) => %{String.t() => float()}}
  def draw(refineries_by_month) do
    Map.new(refineries_by_month, fn {month, refineries} ->
      {month, Map.new(refineries, &{&1.id, sample()})}
    end)
  end

  defp sample, do: @min_yield + :rand.uniform() * (@max_yield - @min_yield)
end
