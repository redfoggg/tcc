defmodule GasolineSimulator.Scenarios.YieldSamplingTest do
  use ExUnit.Case, async: true

  alias GasolineSimulator.Scenarios.YieldSampling

  test "draw/1 returns a map with exactly the same period keys as the input" do
    input = %{
      1 => [%{id: "A", observed_monthly_yields: [0.30]}, %{id: "B", observed_monthly_yields: [0.22]}],
      2 => [%{id: "A", observed_monthly_yields: [0.30]}, %{id: "B", observed_monthly_yields: [0.22]}]
    }

    result = YieldSampling.draw(input)

    assert Map.keys(result) |> Enum.sort() == Map.keys(input) |> Enum.sort()
  end

  test "draw/1 returns exactly the same refinery ids as the input for each period" do
    input = %{
      1 => [%{id: "A", observed_monthly_yields: [0.30]}, %{id: "B", observed_monthly_yields: [0.22]}],
      2 => [%{id: "A", observed_monthly_yields: [0.30]}, %{id: "B", observed_monthly_yields: [0.22]}]
    }

    result = YieldSampling.draw(input)

    for {month, refineries} <- input do
      expected_ids = Enum.map(refineries, & &1.id) |> Enum.sort()
      actual_ids = Map.fetch!(result, month) |> Map.keys() |> Enum.sort()

      assert actual_ids == expected_ids
    end
  end

  test "draw/1 picks a yield from that refinery's own monthly list" do
    input = %{
      1 => [
        %{id: "high", observed_monthly_yields: [0.33, 0.34, 0.37]},
        %{
          id: "low",
          observed_monthly_yields: [0.0, 0.0, 0.05],
          national_average_yield: 0.26
        }
      ]
    }

    result = YieldSampling.draw(input)

    assert result[1]["high"] in [0.33, 0.34, 0.37]
    assert result[1]["low"] in [0.26, 0.05]
  end

  test "draw/1 uses the national average when the drawn yield would be 0" do
    result =
      YieldSampling.draw(%{
        1 => [
          %{id: "idle", observed_monthly_yields: [0.0, 0.0], national_average_yield: 0.26},
          %{id: "missing", national_average_yield: 0.26}
        ]
      })

    assert_in_delta result[1]["idle"], 0.26, 1.0e-12
    assert_in_delta result[1]["missing"], 0.26, 1.0e-12
  end
end
