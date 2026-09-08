defmodule GasolineSimulator.Data.RepositoryTest do
  use ExUnit.Case, async: true

  alias GasolineSimulator.Data.Repository

  test "loads a curated local reference yield with provenance" do
    year_data = Repository.load_year()
    refineries = Map.fetch!(year_data.refineries_by_month, 1)

    replan = Enum.find(refineries, &(&1.id == "REPLAN"))

    assert_in_delta replan.reference_yield, 0.266129, 1.0e-5
    assert replan.reference_yield_provenance == "observed_annual_weighted_ratio"
  end

  test "loads the national fallback reference yield for refineries with an invalid local ratio" do
    year_data = Repository.load_year()
    refineries = Map.fetch!(year_data.refineries_by_month, 1)

    lubnor = Enum.find(refineries, &(&1.id == "LUBNOR"))
    ream = Enum.find(refineries, &(&1.id == "REAM"))

    assert_in_delta lubnor.reference_yield, 0.248352, 1.0e-5
    assert lubnor.reference_yield_provenance == "national_weighted_fallback_zero_local_ratio"

    assert_in_delta ream.reference_yield, 0.248352, 1.0e-5

    assert ream.reference_yield_provenance ==
             "national_weighted_fallback_local_ratio_exceeds_unit_interval"
  end

  test "every fixed-scope refinery is present every month with a positive reference yield" do
    year_data = Repository.load_year()

    Enum.each(Repository.months(), fn month ->
      refineries = Map.fetch!(year_data.refineries_by_month, month)

      assert length(refineries) == 13

      Enum.each(refineries, fn refinery ->
        assert refinery.reference_yield > 0.0
        assert refinery.capacity_m3 >= 0.0
        assert refinery.processing_capacity_m3 >= 0.0
      end)
    end)
  end
end
