defmodule GasolineSimulator.Scenarios.YieldSampling do
  @base_yield 0.20
  @max_plausible_observed_yield 0.40

  @provenance "Simulated gasoline A yield, independently sampled per refinery-month " <>
                "from Uniform(0.20, observed 2025 gasoline A yield) for this planning run. " <>
                "The upper bound is that refinery's annual ratio of observed gasoline A " <>
                "to observed petroleum throughput, or 0.20 when the observed yield is " <>
                "missing, not positive, or above 0.40"

  @spec provenance() :: String.t()
  def provenance, do: @provenance

  @spec draw(%{(1..12) => [map()]}) :: %{(1..12) => %{String.t() => float()}}
  def draw(refineries_by_month) do
    Map.new(refineries_by_month, fn {month, refineries} ->
      {month, Map.new(refineries, &{&1.id, sample(&1)})}
    end)
  end

  defp sample(refinery) do
    cap = yield_cap(refinery)
    @base_yield + :rand.uniform() * (cap - @base_yield)
  end

  defp yield_cap(refinery) do
    observed = Map.get(refinery, :observed_yield)

    cond do
      not is_number(observed) -> @base_yield
      observed < @base_yield -> @base_yield
      observed > @max_plausible_observed_yield -> @base_yield
      true -> observed
    end
  end
end
