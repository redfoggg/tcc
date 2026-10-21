defmodule GasolineSimulator.Refineries.Distances do
  @roads %{
    {"REAM", "RECAP"} => 3876.3,
    {"REAM", "REDUC"} => 4247.6,
    {"REAM", "REFAP"} => 4425.8,
    {"REAM", "REFMAT"} => 4586.1,
    {"REAM", "REGAP"} => 3889.3,
    {"REAM", "REPAR"} => 4008.9,
    {"REAM", "REPLAN"} => 3750.6,
    {"REAM", "REVAP"} => 3924.1,
    {"REAM", "RPBC"} => 3917.6,
    {"REAM", "RPCC"} => 4524.5,
    {"RECAP", "REDUC"} => 444.3,
    {"RECAP", "REFAP"} => 1173.2,
    {"RECAP", "REFMAT"} => 1937.1,
    {"RECAP", "REGAP"} => 577.4,
    {"RECAP", "REPAR"} => 470.0,
    {"RECAP", "REPLAN"} => 150.2,
    {"RECAP", "REVAP"} => 117.1,
    {"RECAP", "RPBC"} => 54.4,
    {"RECAP", "RPCC"} => 2930.1,
    {"REDUC", "REFAP"} => 1560.5,
    {"REDUC", "REFMAT"} => 1553.3,
    {"REDUC", "REGAP"} => 420.3,
    {"REDUC", "REPAR"} => 857.3,
    {"REDUC", "REPLAN"} => 505.1,
    {"REDUC", "REVAP"} => 328.3,
    {"REDUC", "RPBC"} => 477.8,
    {"REDUC", "RPCC"} => 2546.3,
    {"REFAP", "REFMAT"} => 3042.9,
    {"REFAP", "REGAP"} => 1683.2,
    {"REFAP", "REPAR"} => 740.2,
    {"REFAP", "REPLAN"} => 1230.1,
    {"REFAP", "REVAP"} => 1232.9,
    {"REFAP", "RPBC"} => 1117.6,
    {"REFAP", "RPCC"} => 4036.0,
    {"REFMAT", "REGAP"} => 1367.2,
    {"REFMAT", "REPAR"} => 2465.1,
    {"REFMAT", "REPLAN"} => 1975.6,
    {"REFMAT", "REVAP"} => 1886.4,
    {"REFMAT", "RPBC"} => 1979.6,
    {"REFMAT", "RPCC"} => 1135.2,
    {"REGAP", "REPAR"} => 986.5,
    {"REGAP", "REPLAN"} => 584.9,
    {"REGAP", "REVAP"} => 526.1,
    {"REGAP", "RPBC"} => 619.3,
    {"REGAP", "RPCC"} => 2358.7,
    {"REPAR", "REPLAN"} => 533.2,
    {"REPAR", "REVAP"} => 536.0,
    {"REPAR", "RPBC"} => 420.7,
    {"REPAR", "RPCC"} => 3459.6,
    {"REPLAN", "REVAP"} => 190.2,
    {"REPLAN", "RPBC"} => 194.8,
    {"REPLAN", "RPCC"} => 2977.8,
    {"REVAP", "RPBC"} => 154.8,
    {"REVAP", "RPCC"} => 2877.8,
    {"RPBC", "RPCC"} => 2971.4
  }

  def pairs, do: @roads |> Map.keys() |> Enum.sort()

  def transit_days(origin, destination) do
    km = Map.fetch!(@roads, pair(origin, destination))
    max(ceil(km / (60 * 24)), 1)
  end

  def pair({origin, destination}) do
    [first, second] = Enum.sort([origin, destination])
    {first, second}
  end

  def pair(origin, destination), do: pair({origin, destination})

  def pair_key(pair) do
    {origin, destination} = pair(pair)
    origin <> "|" <> destination
  end
end
