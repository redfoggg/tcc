defmodule GasolineSimulator.Data.Regions do
  alias GasolineSimulator.Data.Catalog

  # IBGE 2022 Census. Center-West has no refinery in the catalog, so its
  # population is merged into the Southeast demand region.
  @north_population 17_354_884
  @northeast_population 54_658_515
  @southeast_population 84_840_113
  @center_west_population 16_289_538
  @south_population 29_937_706

  @population %{
    north: @north_population,
    northeast: @northeast_population,
    southeast: @southeast_population + @center_west_population,
    south: @south_population
  }

  @uf %{
    "AC" => :north,
    "AP" => :north,
    "AM" => :north,
    "PA" => :north,
    "RO" => :north,
    "RR" => :north,
    "TO" => :north,
    "AL" => :northeast,
    "BA" => :northeast,
    "CE" => :northeast,
    "MA" => :northeast,
    "PB" => :northeast,
    "PE" => :northeast,
    "PI" => :northeast,
    "RN" => :northeast,
    "SE" => :northeast,
    "DF" => :southeast,
    "GO" => :southeast,
    "MT" => :southeast,
    "MS" => :southeast,
    "ES" => :southeast,
    "MG" => :southeast,
    "RJ" => :southeast,
    "SP" => :southeast,
    "PR" => :south,
    "RS" => :south,
    "SC" => :south
  }

  def ids, do: Map.keys(@population)

  def of_plant(id), do: Map.fetch!(@uf, Catalog.find(id).uf)

  def demand(national_m3, region) when is_number(national_m3) do
    national_m3 * (@population[region] / total_population())
  end

  defp total_population, do: Enum.sum(Map.values(@population))
end
