defmodule GasolineSimulator.Scenarios.RunnerTest do
  use ExUnit.Case, async: true

  alias GasolineSimulator.Data.Catalog
  alias GasolineSimulator.Data.Repository
  alias GasolineSimulator.Scenarios.Runner

  @moduletag :annual_smoke
  @moduletag timeout: 120_000

  test "the planned annual run solves every 2025 day and aggregates twelve months" do
    assert {:ok, %{days: days, months: months, annual: annual}} = Runner.run(%{}, min_year_ms: 0)

    assert length(days) == 365
    assert length(months) == 12
    assert Enum.all?(days, &(&1.status == :ok))
    assert Enum.all?(months, &(&1.status == :ok))

    assert Enum.map(days, & &1.month) == Enum.map(Repository.days(), &Repository.day_key/1)

    assert Enum.map(months, & &1.month) ==
             Enum.map(1..12, &("2025-" <> String.pad_leading(Integer.to_string(&1), 2, "0")))

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

    alive_count = length(GasolineSimulator.Refineries.Supervisor.alive_ids())
    assert Enum.all?(days, &(length(&1.refineries) == alive_count))
    assert Enum.all?(months, &(length(&1.refineries) == alive_count))

    assert Enum.all?(days, fn day ->
             Enum.all?(day.refineries, fn refinery ->
               nameplate = refinery.processing_capacity_m3
               gasoline_from_petroleum = refinery.simulated_yield * nameplate
               min_petroleum = 0.40 * nameplate

               refinery.floor_m3 <= refinery.capacity_m3 + 1.0e-6 and
                 refinery.capacity_m3 <= gasoline_from_petroleum + 1.0e-6 and
                 refinery.allocated_m3 <= gasoline_from_petroleum + 1.0e-6 and
                 refinery.petroleum_processed_m3 <= nameplate + 1.0e-6 and
                 (not refinery.active or
                    refinery.petroleum_processed_m3 + 1.0e-6 >= min_petroleum)
             end)
           end)

    assert Enum.all?(days, &(&1.production_m3 > 0.0))
    assert annual.total_fut_pct >= 0.0
    assert annual.total_fut_pct <= 100.0 + 1.0e-4

    assert_in_delta annual.total_fut_pct,
                    annual.total_petroleum_processed_m3 / annual.total_processing_capacity_m3 *
                      100.0,
                    1.0e-6

    assert Enum.any?(days, fn day ->
             Enum.any?(day.refineries, fn refinery ->
               refinery.petroleum_processed_m3 >
                 GasolineSimulator.Models.Problem.sustainable_utilization_ratio() *
                   refinery.processing_capacity_m3 + 1.0
             end)
           end)

    deficit_days = Enum.filter(days, &(&1.deficit_m3 > 1.0))

    assert deficit_days != []

    assert Enum.all?(deficit_days, fn day ->
             Enum.all?(day.refineries, fn refinery ->
               refinery.capacity_m3 <= 1.0e-9 or
                 (refinery.active and refinery.allocated_m3 + 1.0e-3 >= refinery.capacity_m3)
             end)
           end)
  end

  test "after hitting 100% FUT the cap only falls and then locks from surplus above 90%" do
    assert {:ok, %{days: days}} = Runner.run(%{}, min_year_ms: 0)
    burst = GasolineSimulator.Models.Problem.burst_utilization_ratio()
    sustainable = GasolineSimulator.Models.Problem.sustainable_utilization_ratio()

    days
    |> hd()
    |> Map.fetch!(:refineries)
    |> Enum.map(& &1.id)
    |> Enum.each(fn id ->
      initial = %{phase: :open, ratio: burst, surplus: 0.0, lock_left: 0}

      Enum.reduce(days, initial, fn day, state ->
        refinery = Enum.find(day.refineries, &(&1.id == id))
        cap = state.ratio * refinery.processing_capacity_m3
        assert refinery.petroleum_processed_m3 <= cap + 1.0e-6

        fut =
          if refinery.processing_capacity_m3 > 0.0 do
            refinery.petroleum_processed_m3 / refinery.processing_capacity_m3
          else
            0.0
          end

        next_state(state, fut, burst, sustainable)
      end)
    end)
  end

  defp next_state(%{phase: phase} = state, fut, burst, sustainable)
       when phase in [:open, :falling] do
    surplus = state.surplus + max(fut - sustainable, 0.0)
    advance_test_phase(%{state | surplus: surplus}, fut, burst, sustainable)
  end

  defp next_state(%{phase: :locked, lock_left: left} = state, _fut, burst, _sustainable) do
    left = left - 1

    if left <= 0 do
      %{phase: :open, ratio: burst, surplus: 0.0, lock_left: 0}
    else
      %{state | lock_left: left}
    end
  end

  defp advance_test_phase(%{phase: :open, ratio: ratio} = state, fut, burst, _sustainable) do
    if fut + 1.0e-6 >= 0.99 * burst do
      %{state | phase: :falling, ratio: ratio - 0.01}
    else
      state
    end
  end

  defp advance_test_phase(
         %{phase: :falling, ratio: ratio, surplus: surplus} = state,
         _fut,
         _burst,
         sustainable
       ) do
    next_ratio = ratio - 0.01

    if next_ratio <= sustainable + 1.0e-12 do
      lock_left = surplus |> Kernel./(0.01) |> Float.ceil() |> trunc() |> max(1)
      %{state | phase: :locked, ratio: sustainable, lock_left: lock_left}
    else
      %{state | ratio: next_ratio}
    end
  end

  test "monthly served demand changes across independent planning runs" do
    assert {:ok, %{months: first}} = Runner.run(%{}, min_year_ms: 0)
    assert {:ok, %{months: second}} = Runner.run(%{}, min_year_ms: 0)

    first_served = Enum.map(first, & &1.served_demand_m3)
    second_served = Enum.map(second, & &1.served_demand_m3)

    delta =
      first_served
      |> Enum.zip(second_served)
      |> Enum.map(fn {left, right} -> abs(left - right) end)
      |> Enum.max()

    assert delta > 1_000.0
  end

  test "every refinery-day simulated yield is one of that plant's 2025 monthly yields" do
    year_data = Repository.load_year()

    plants =
      year_data.refineries_by_day
      |> Map.values()
      |> List.flatten()
      |> Map.new(&{&1.id, &1})

    assert {:ok, %{days: days}} = Runner.run(%{}, min_year_ms: 0)

    for day <- days, refinery <- day.refineries do
      plant = Map.fetch!(plants, refinery.id)
      allowed = plant.observed_monthly_yields ++ [plant.national_average_yield]

      assert Enum.any?(allowed, fn yield ->
               abs(yield - refinery.simulated_yield) <= 1.0e-9
             end)
    end
  end

  test "on_day is called once for every solved day" do
    {:ok, agent} = Agent.start_link(fn -> 0 end)

    assert {:ok, %{days: days}} =
             Runner.run(%{}, min_year_ms: 0, on_day: fn _day -> Agent.update(agent, &(&1 + 1)) end)

    assert Agent.get(agent, & &1) == length(days)
    assert length(days) == 365
  end

  test "a rejoined plant ramps from 40 percent instead of jumping to 100" do
    down = MapSet.new(Date.range(~D[2025-02-01], ~D[2025-02-10]))

    alive_ids = fn day ->
      if MapSet.member?(down, day), do: Catalog.ids() -- ["REPAR"], else: Catalog.ids()
    end

    assert {:ok, %{days: days}} = Runner.run(%{}, min_year_ms: 0, alive_ids: alive_ids)
    by_day = Map.new(days, &{&1.month, &1})

    refute Enum.any?(by_day["2025-02-01"].refineries, &(&1.id == "REPAR"))

    first = Enum.find(by_day["2025-02-11"].refineries, &(&1.id == "REPAR"))
    second = Enum.find(by_day["2025-02-12"].refineries, &(&1.id == "REPAR"))

    assert_in_delta utilization_cap(first), 0.40, 1.0e-6
    assert_in_delta utilization_cap(second), 0.41, 1.0e-6
  end

  test "the sampled simulated yield is the same value used throughout the result for that run" do
    assert {:ok, %{days: days}} = Runner.run(%{}, min_year_ms: 0)

    for day <- days, refinery <- day.refineries do
      if refinery.simulated_yield <= 0.0 do
        assert_in_delta refinery.allocated_m3, 0.0, 1.0e-9
        assert_in_delta refinery.petroleum_processed_m3, 0.0, 1.0e-9
      else
        assert_in_delta refinery.petroleum_processed_m3,
                        refinery.allocated_m3 / refinery.simulated_yield,
                        1.0e-6
      end
    end
  end

  defp utilization_cap(refinery) do
    refinery.capacity_m3 / (refinery.simulated_yield * refinery.processing_capacity_m3)
  end
end
