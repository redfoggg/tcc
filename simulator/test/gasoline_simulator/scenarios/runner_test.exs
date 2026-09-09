defmodule GasolineSimulator.Scenarios.RunnerTest do
  use ExUnit.Case, async: true

  alias GasolineSimulator.Data.Historical
  alias GasolineSimulator.Models.Plan
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
             Enum.all?(month.refineries, fn refinery ->
               gasoline_from_petroleum =
                 refinery.simulated_yield * refinery.processing_capacity_m3

               min_petroleum = 0.40 * refinery.processing_capacity_m3

               refinery.floor_m3 <= refinery.capacity_m3 + 1.0e-6 and
                 refinery.capacity_m3 <= gasoline_from_petroleum + 1.0e-6 and
                 refinery.allocated_m3 <= gasoline_from_petroleum + 1.0e-6 and
                 refinery.petroleum_processed_m3 <= refinery.processing_capacity_m3 + 1.0e-6 and
                 (not refinery.active or
                    refinery.petroleum_processed_m3 + 1.0e-6 >= min_petroleum)
             end)
           end)

    assert Enum.all?(months, &(&1.production_m3 > 0.0))
    assert annual.total_fut_pct >= 0.0
    assert annual.total_fut_pct <= 90.0 + 1.0e-4

    assert_in_delta annual.total_fut_pct,
                    annual.total_petroleum_processed_m3 / annual.total_processing_capacity_m3 *
                      100.0,
                    1.0e-6

    futs = Enum.map(months, & &1.total_fut_pct)
    assert Enum.max(futs) - Enum.min(futs) > 5.0
  end

  test "each month's petroleum cap follows leftover budget minus later months' demand over simulated yield" do
    year_data = GasolineSimulator.Data.Repository.load_year()
    assert {:ok, %{months: months, annual: annual}} = Runner.run(%{})

    oil_need_by_month =
      Map.new(Enum.zip(1..12, months), fn {month, result} ->
        demand = Map.fetch!(year_data.demand_by_month, month).demand_m3
        capacity = result.total_processing_capacity_m3

        mean_yield =
          Enum.sum(Enum.map(result.refineries, &(&1.simulated_yield * &1.processing_capacity_m3))) /
            capacity

        {month, demand / mean_yield}
      end)

    annual_oil_need = oil_need_by_month |> Map.values() |> Enum.sum()
    budget = 0.90 * annual.total_processing_capacity_m3

    {pairs, _leftover} =
      Enum.map_reduce(Enum.zip(1..12, months), budget, fn {month, result}, remaining ->
        future_need =
          oil_need_by_month
          |> Enum.filter(fn {later, _need} -> later > month end)
          |> Enum.map(fn {_later, need} -> need end)
          |> Enum.sum()

        reserved = budget * future_need / annual_oil_need
        cap = min(result.total_processing_capacity_m3, max(remaining - reserved, 0.0))
        leftover = max(remaining - result.total_petroleum_processed_m3, 0.0)
        {{result, cap}, leftover}
      end)

    for {result, cap} <- pairs do
      assert result.total_petroleum_processed_m3 <= cap + 1.0
    end
  end

  test "monthly FUT pattern changes across independent planning runs" do
    assert {:ok, %{months: first}} = Runner.run(%{})
    assert {:ok, %{months: second}} = Runner.run(%{})

    first_futs = Enum.map(first, & &1.total_fut_pct)
    second_futs = Enum.map(second, & &1.total_fut_pct)

    delta =
      first_futs
      |> Enum.zip(second_futs)
      |> Enum.map(fn {left, right} -> abs(left - right) end)
      |> Enum.max()

    assert delta > 0.2
  end

  test "every refinery-month simulated yield stays between 0.20 and that plant's observed 2025 yield" do
    year_data = GasolineSimulator.Data.Repository.load_year()

    observed_by_id =
      year_data.refineries_by_month
      |> Map.values()
      |> List.flatten()
      |> Map.new(&{&1.id, &1.observed_yield})

    assert {:ok, %{months: months}} = Runner.run(%{})

    for month <- months, refinery <- month.refineries do
      cap =
        case Map.get(observed_by_id, refinery.id) do
          yield when is_number(yield) and yield >= 0.20 and yield <= 0.40 -> yield
          _ -> 0.20
        end

      assert refinery.simulated_yield >= 0.20
      assert refinery.simulated_yield <= cap + 1.0e-12
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
    assert is_map(export.planned.mechanics)

    for {month, export_month} <- Enum.zip(months, export.planned.mechanics.months) do
      for {refinery, exported} <- Enum.zip(month.refineries, export_month.refineries) do
        assert_in_delta exported.simulated_yield, refinery.simulated_yield, 1.0e-12
      end
    end

    assert_in_delta export.planned.annual.total_fut_pct,
                    result.annual.total_fut_pct,
                    1.0e-6
  end
end
