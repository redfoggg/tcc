defmodule GasolineSimulator.Data.RepositoryTest do
  use ExUnit.Case, async: true

  alias GasolineSimulator.Data.Repository

  test "monthly yields keep only plant-months with crude and A at most equal to crude" do
    year_data = Repository.load_year()

    yields_by_id =
      year_data.refineries_by_day
      |> Map.values()
      |> List.flatten()
      |> Map.new(&{&1.id, &1.observed_monthly_yields})

    assert yields_by_id["REAM"] == [0.0, 0.0]
    refute Map.has_key?(yields_by_id, "LUBNOR")
    assert length(yields_by_id["REVAP"]) == 11
    assert Enum.max(yields_by_id["REVAP"]) < 1.0
    assert Enum.max(yields_by_id["RECAP"]) > 0.40
    assert Enum.min(yields_by_id["REPAR"]) > 0.30

    national =
      year_data.refineries_by_day
      |> Map.values()
      |> List.flatten()
      |> hd()
      |> Map.fetch!(:national_average_yield)

    assert_in_delta national, 0.2628, 1.0e-3
  end
end
