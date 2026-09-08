defmodule GasolineSimulator.Data.RepositoryTest do
  use ExUnit.Case, async: true

  alias GasolineSimulator.Data.Repository

  test "loads curated capacity and floor attributes with provenance" do
    year_data = Repository.load_year()
    refineries = Map.fetch!(year_data.refineries_by_month, 1)

    replan = Enum.find(refineries, &(&1.id == "REPLAN"))

    assert_in_delta replan.capacity_m3, 578_026.059, 1.0e-3
    assert_in_delta replan.processing_capacity_m3, 2_138_991.384, 1.0e-3
    assert replan.floor_provenance == "observed_minimum_2025"
  end

  test "every fixed-scope refinery is present every month with positive capacity fields" do
    year_data = Repository.load_year()

    Enum.each(Repository.months(), fn month ->
      refineries = Map.fetch!(year_data.refineries_by_month, month)

      assert length(refineries) == 13

      Enum.each(refineries, fn refinery ->
        assert refinery.capacity_m3 >= 0.0
        assert refinery.processing_capacity_m3 >= 0.0
        refute Map.has_key?(refinery, :simulated_yield)
      end)
    end)
  end
end
