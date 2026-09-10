defmodule GasolineSimulator.Models.ProblemTest do
  use ExUnit.Case, async: true

  alias GasolineSimulator.Models.Problem

  test "gasoline cap follows the plant yield and oil cap, not a national-average column" do
    {:ok, problem} =
      Problem.build(%{
        month: "2025-01",
        demand_m3: 1_000.0,
        initial_inventory_m3: 0.0,
        max_petroleum_m3: 1_000.0,
        refineries: [
          %{
            id: "REPAR",
            name: "REPAR",
            uf: "PR",
            capacity_m3: 26.0,
            processing_capacity_m3: 100.0,
            simulated_yield: 0.34,
            floor_m3: 0.0,
            max_utilization_ratio: 1.0
          }
        ]
      })

    [refinery] = problem.refineries
    assert_in_delta refinery.capacity_m3, 34.0, 1.0e-9
  end

  test "a zero yield plant has no gasoline cap" do
    {:ok, problem} =
      Problem.build(%{
        month: "2025-01",
        demand_m3: 1_000.0,
        initial_inventory_m3: 0.0,
        max_petroleum_m3: 1_000.0,
        refineries: [
          %{
            id: "IDLE",
            name: "IDLE",
            uf: "CE",
            capacity_m3: 26.0,
            processing_capacity_m3: 100.0,
            simulated_yield: 0.0,
            floor_m3: 0.0,
            max_utilization_ratio: 1.0
          }
        ]
      })

    [refinery] = problem.refineries
    assert_in_delta refinery.capacity_m3, 0.0, 1.0e-12
    assert_in_delta refinery.floor_m3, 0.0, 1.0e-12
  end
end
