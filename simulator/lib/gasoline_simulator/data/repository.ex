defmodule GasolineSimulator.Data.Repository do
  alias GasolineSimulator.Catalog

  @reference_yields_file "anp_2025_reference_yields_by_refinery.csv"
  @refinery_capacity_file "anp_2025_refinery_capacity_monthly.csv"
  @demand_proxy_file "anp_2025_demand_proxy_national_monthly.csv"

  @national_fallback_row_id "NATIONAL_FALLBACK"

  @spec months() :: [1..12]
  def months, do: Enum.to_list(1..12)

  @spec month_key(1..12) :: String.t()
  def month_key(month) when month in 1..12,
    do: "2025-" <> String.pad_leading(Integer.to_string(month), 2, "0")

  @spec load_year(keyword()) :: map()
  def load_year(opts \\ []) do
    curated_dir = curated_dir(opts)
    reference_yields_by_refinery = read_reference_yields(curated_dir)

    %{
      demand_by_month: demand_by_month(curated_dir),
      refineries_by_month: refineries_by_month(curated_dir, reference_yields_by_refinery)
    }
  end

  defp curated_dir(opts) do
    data_dir =
      Keyword.get(opts, :data_dir, Application.fetch_env!(:gasoline_simulator, :data_dir))

    Path.join(data_dir, "curated")
  end

  defp demand_by_month(curated_dir) do
    curated_dir
    |> Path.join(@demand_proxy_file)
    |> read_csv_rows()
    |> Map.new(fn row ->
      {month_index(row["month"]),
       %{
         demand_m3: parse_float(row["gasolina_a_equivalent_m3"]),
         demand_provenance:
           "sales-derived gasoline A equivalent demand proxy " <>
             "(gasolina_c_sales_m3=#{row["gasolina_c_sales_m3"]}, " <>
             "ethanol_anidro_fraction_assumed=#{row["ethanol_anidro_fraction_assumed"]}, " <>
             "demand_proxy_provenance=#{row["demand_proxy_provenance"]}, " <>
             "assumption_ref=#{row["assumption_ref"]})"
       }}
    end)
  end

  defp refineries_by_month(curated_dir, reference_yields_by_refinery) do
    curated_dir
    |> Path.join(@refinery_capacity_file)
    |> read_csv_rows()
    |> Enum.group_by(&month_index(&1["month"]))
    |> Map.new(fn {month, rows} ->
      {month, Enum.map(rows, &to_refinery_attrs(&1, reference_yields_by_refinery))}
    end)
  end

  defp read_reference_yields(curated_dir) do
    curated_dir
    |> Path.join(@reference_yields_file)
    |> read_csv_rows()
    |> Enum.reject(&(&1["refinery_code"] == @national_fallback_row_id))
    |> Map.new(fn row ->
      {row["refinery_code"],
       %{
         reference_yield: parse_float(row["reference_yield"]),
         reference_yield_provenance: row["provenance"]
       }}
    end)
  end

  defp to_refinery_attrs(capacity_row, reference_yields_by_refinery) do
    reference_yield_entry =
      Map.fetch!(reference_yields_by_refinery, capacity_row["refinery_code"])

    catalog_entry = Catalog.find(capacity_row["refinery_code"])

    %{
      id: capacity_row["refinery_code"],
      name: catalog_entry.name,
      uf: catalog_entry.uf,
      capacity_m3: parse_float(capacity_row["capacity_gasoline_a_m3_month"]),
      processing_capacity_m3: parse_float(capacity_row["capacity_m3_month"]),
      floor_m3: parse_float(capacity_row["operating_floor_m3_2025"]),
      floor_provenance: capacity_row["operating_floor_provenance"],
      reference_yield: reference_yield_entry.reference_yield,
      reference_yield_provenance: reference_yield_entry.reference_yield_provenance
    }
  end

  defp month_index(month_key),
    do: month_key |> String.split("-") |> List.last() |> String.to_integer()

  defp read_csv_rows(path) do
    [header | data_rows] =
      path
      |> File.read!()
      |> String.split(~r/\r\n|\n/, trim: true)
      |> Enum.map(&String.split(&1, ","))

    Enum.map(data_rows, fn columns -> header |> Enum.zip(columns) |> Map.new() end)
  end

  defp parse_float(value) do
    {number, ""} = Float.parse(value)
    number
  end
end
