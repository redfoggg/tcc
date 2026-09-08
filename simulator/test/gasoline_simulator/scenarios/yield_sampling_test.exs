defmodule GasolineSimulator.Scenarios.YieldSamplingTest do
  use ExUnit.Case, async: true

  alias GasolineSimulator.Scenarios.YieldSampling

  test "draw/1 returns a map with exactly the same month keys as the input" do
    input = %{
      1 => [%{id: "A"}, %{id: "B"}],
      2 => [%{id: "A"}, %{id: "B"}]
    }

    result = YieldSampling.draw(input)

    assert Map.keys(result) |> Enum.sort() == Map.keys(input) |> Enum.sort()
  end

  test "draw/1 returns exactly the same refinery ids as the input for each month" do
    input = %{
      1 => [%{id: "A"}, %{id: "B"}],
      2 => [%{id: "A"}, %{id: "B"}]
    }

    result = YieldSampling.draw(input)

    for {month, refineries} <- input do
      expected_ids = Enum.map(refineries, & &1.id) |> Enum.sort()
      actual_ids = Map.fetch!(result, month) |> Map.keys() |> Enum.sort()

      assert actual_ids == expected_ids
    end
  end

  test "draw/1 samples every value within the calibrated 0.20-0.25 range" do
    input = %{
      1 => [%{id: "A"}, %{id: "B"}],
      2 => [%{id: "A"}, %{id: "B"}]
    }

    result = YieldSampling.draw(input)

    for {_month, yields_by_refinery} <- result, {_id, yield} <- yields_by_refinery do
      assert is_float(yield)
      assert yield >= 0.20
      assert yield <= 0.25
    end
  end

  test "provenance/0 returns a non-empty string describing the sampling distribution" do
    provenance = YieldSampling.provenance()

    assert is_binary(provenance)
    refute provenance == ""
    assert provenance =~ "Uniform"
    assert provenance =~ "0.20"
    assert provenance =~ "0.25"
    assert provenance =~ "refinery-month"
  end
end
