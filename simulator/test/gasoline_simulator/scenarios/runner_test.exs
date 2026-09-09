defmodule GasolineSimulator.Scenarios.RunnerTest do
  use ExUnit.Case, async: true

  alias GasolineSimulator.Data.Repository
  alias GasolineSimulator.Scenarios.Runner

  @moduletag :annual_smoke
  @moduletag timeout: 120_000

  test "the planned annual run solves every 2025 day and aggregates twelve months" do
    assert {:ok, %{days: days, months: months, annual: annual}} = Runner.run(%{})

    assert length(days) == 365
    assert length(months) == 12
    assert Enum.all?(days, &(&1.status == :ok))
    assert Enum.all?(months, &(&1.status == :ok))

    assert Enum.map(days, & &1.month) == Enum.map(Repository.days(), &Repository.day_key/1)

    assert Enum.map(months, & &1.month) == Enum.map(1..12, &Repository.month_key/1)

    days
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.each(fn [prior, current] ->
      assert_in_delta prior.ending_inventory_m3, current.starting_inventory_m3, 1.0e-6
    end)

    months
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.each(fn [prior, current] ->
      assert_in_delta prior.ending_inventory_m3, current.starting_inventory_m3, 1.0e-6
    end)

    assert_in_delta annual.starting_inventory_m3, List.first(days).starting_inventory_m3, 1.0e-6
    assert_in_delta annual.ending_inventory_m3, List.last(days).ending_inventory_m3, 1.0e-6
    assert_in_delta annual.demand_m3, Enum.sum(Enum.map(days, & &1.demand_m3)), 1.0e-3
    assert_in_delta annual.demand_m3, Enum.sum(Enum.map(months, & &1.demand_m3)), 1.0e-3

    assert Enum.all?(days, &(length(&1.refineries) == 13))
    assert Enum.all?(months, &(length(&1.refineries) == 13))

    assert Enum.all?(days, fn day ->
             Enum.all?(day.refineries, fn refinery ->
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

    assert Enum.all?(days, &(&1.production_m3 > 0.0))
    assert annual.total_fut_pct >= 0.0
    assert annual.total_fut_pct <= 90.0 + 1.0e-4

    assert_in_delta annual.total_fut_pct,
                    annual.total_petroleum_processed_m3 / annual.total_processing_capacity_m3 *
                      100.0,
                    1.0e-6

    futs = Enum.map(months, & &1.total_fut_pct)
    assert Enum.max(futs) - Enum.min(futs) > 5.0
  end

  test "each day's petroleum cap follows leftover budget minus later days' demand over simulated yield" do
    year_data = Repository.load_year()
    assert {:ok, %{days: days, annual: annual}} = Runner.run(%{})

    oil_need_by_day =
      Map.new(Enum.zip(Repository.days(), days), fn {day, result} ->
        demand = Map.fetch!(year_data.demand_by_day, day).demand_m3
        capacity = result.total_processing_capacity_m3

        mean_yield =
          Enum.sum(Enum.map(result.refineries, &(&1.simulated_yield * &1.processing_capacity_m3))) /
            capacity

        {day, demand / mean_yield}
      end)

    annual_oil_need = oil_need_by_day |> Map.values() |> Enum.sum()
    budget = 0.90 * annual.total_processing_capacity_m3

    {pairs, _leftover} =
      Enum.map_reduce(Enum.zip(Repository.days(), days), budget, fn {day, result}, remaining ->
        future_need =
          oil_need_by_day
          |> Enum.filter(fn {later, _need} -> Date.compare(later, day) == :gt end)
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

  test "every refinery-day simulated yield stays between 0.20 and that plant's observed 2025 yield" do
    year_data = Repository.load_year()

    observed_by_id =
      year_data.refineries_by_day
      |> Map.values()
      |> List.flatten()
      |> Map.new(&{&1.id, &1.observed_yield})

    assert {:ok, %{days: days}} = Runner.run(%{})

    for day <- days, refinery <- day.refineries do
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
    assert {:ok, %{days: days}} = Runner.run(%{})

    for day <- days, refinery <- day.refineries do
      assert_in_delta refinery.petroleum_processed_m3,
                      refinery.allocated_m3 / refinery.simulated_yield,
                      1.0e-6
    end
  end
end
