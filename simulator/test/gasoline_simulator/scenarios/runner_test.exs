defmodule GasolineSimulator.Scenarios.RunnerTest do
  use ExUnit.Case, async: true

  alias GasolineSimulator.Historical
  alias GasolineSimulator.Scenarios.Plan
  alias GasolineSimulator.Scenarios.PlanningExport
  alias GasolineSimulator.Scenarios.Runner

  @moduletag :annual_smoke

  test "the planned annual run solves all twelve 2025 months against the curated dataset" do
    assert {:ok, %{months: months, annual: annual}} = Runner.run(%{})

    assert length(months) == 12
    assert Enum.all?(months, &(&1.status == :ok))

    assert Enum.map(months, & &1.month) ==
             Enum.map(1..12, &GasolineSimulator.Data.Repository.month_key/1)

    months
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.each(fn [prior, current] ->
      assert_in_delta prior.ending_inventory_m3, current.starting_inventory_m3, 1.0e-6
    end)

    assert_in_delta annual.starting_inventory_m3, List.first(months).starting_inventory_m3, 1.0e-6
    assert_in_delta annual.ending_inventory_m3, List.last(months).ending_inventory_m3, 1.0e-6
    assert_in_delta annual.demand_m3, Enum.sum(Enum.map(months, & &1.demand_m3)), 1.0e-3

    assert Enum.all?(months, fn month ->
             Enum.all?(month.refineries, &(&1.fut_pct >= 0.0))
           end)

    assert Enum.all?(months, &(length(&1.refineries) == 13))

    assert Enum.all?(months, fn month ->
             Enum.all?(month.refineries, &(&1.floor_m3 <= &1.capacity_m3))
           end)

    assert annual.total_fut_pct >= 0.0

    assert_in_delta annual.total_fut_pct,
                    annual.total_petroleum_processed_m3 / annual.total_processing_capacity_m3 *
                      100.0,
                    1.0e-6
  end

  test "every refinery-month simulated yield falls in the calibrated 0.20-0.25 range" do
    assert {:ok, %{months: months}} = Runner.run(%{})

    for month <- months, refinery <- month.refineries do
      assert refinery.simulated_yield >= 0.20
      assert refinery.simulated_yield <= 0.25
    end
  end

  test "the sampled simulated yield is the same value used throughout the result for that run" do
    assert {:ok, %{months: months} = result} = Runner.run(%{})

    for month <- months, refinery <- month.refineries do
      assert_in_delta refinery.petroleum_processed_m3,
                      refinery.allocated_m3 / refinery.simulated_yield,
                      1.0e-6
    end

    historical = Historical.load()

    plan = %Plan{
      id: "runner-test-plan",
      params: %{},
      status: :completed,
      result: result,
      started_at: DateTime.utc_now(),
      completed_at: DateTime.utc_now()
    }

    export = PlanningExport.build(historical, plan)

    assert export.planned.status == :completed

    assert_in_delta export.planned.annual.total_fut_pct,
                    result.annual.total_fut_pct,
                    1.0e-6
  end

  test "independent annual runs draw different simulated yields for the same refinery-month" do
    assert {:ok, %{months: months_a}} = Runner.run(%{})
    assert {:ok, %{months: months_b}} = Runner.run(%{})

    yields_a =
      Enum.flat_map(months_a, fn month -> Enum.map(month.refineries, & &1.simulated_yield) end)

    yields_b =
      Enum.flat_map(months_b, fn month -> Enum.map(month.refineries, & &1.simulated_yield) end)

    refute yields_a == yields_b
  end
end
