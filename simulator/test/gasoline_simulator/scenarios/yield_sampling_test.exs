defmodule GasolineSimulator.Scenarios.YieldSamplingTest do
  use ExUnit.Case, async: true

  alias GasolineSimulator.Scenarios.YieldSampling

  test "draw/1 returns a map with exactly the same month keys as the input" do
    input = %{
      1 => [%{id: "A", observed_yield: 0.30}, %{id: "B", observed_yield: 0.22}],
      2 => [%{id: "A", observed_yield: 0.30}, %{id: "B", observed_yield: 0.22}]
    }

    result = YieldSampling.draw(input)

    assert Map.keys(result) |> Enum.sort() == Map.keys(input) |> Enum.sort()
  end

  test "draw/1 returns exactly the same refinery ids as the input for each month" do
    input = %{
      1 => [%{id: "A", observed_yield: 0.30}, %{id: "B", observed_yield: 0.22}],
      2 => [%{id: "A", observed_yield: 0.30}, %{id: "B", observed_yield: 0.22}]
    }

    result = YieldSampling.draw(input)

    for {month, refineries} <- input do
      expected_ids = Enum.map(refineries, & &1.id) |> Enum.sort()
      actual_ids = Map.fetch!(result, month) |> Map.keys() |> Enum.sort()

      assert actual_ids == expected_ids
    end
  end

  test "draw/1 samples between 0.20 and the observed yield of that refinery" do
    input = %{
      1 => [%{id: "high", observed_yield: 0.34}, %{id: "low", observed_yield: 0.05}]
    }

    result = YieldSampling.draw(input)
    high = result[1]["high"]
    low = result[1]["low"]

    assert high >= 0.20
    assert high <= 0.34
    assert_in_delta low, 0.20, 1.0e-12
  end

  test "draw/1 uses 0.20 when the observed yield is missing or implausible" do
    result =
      YieldSampling.draw(%{
        1 => [%{id: "missing"}, %{id: "impossible", observed_yield: 3.24}]
      })

    assert_in_delta result[1]["missing"], 0.20, 1.0e-12
    assert_in_delta result[1]["impossible"], 0.20, 1.0e-12
  end

  test "provenance/0 describes the 0.20-to-observed draw" do
    provenance = YieldSampling.provenance()

    assert is_binary(provenance)
    refute provenance == ""
    assert provenance =~ "Uniform"
    assert provenance =~ "0.20"
    assert provenance =~ "observed"
    assert provenance =~ "refinery-month"
  end
end
