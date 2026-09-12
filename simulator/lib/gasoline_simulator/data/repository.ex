defmodule GasolineSimulator.Data.Repository do
  alias GasolineSimulator.Data.Catalog

  @year 2025
  @refinery_capacity_file "anp_2025_refinery_capacity_monthly.csv"
  @demand_proxy_file "anp_2025_demand_proxy_national_monthly.csv"
  @production_file "anp_2025_gasoline_a_production_by_refinery_monthly.csv"

  @spec days() :: [Date.t()]
  def days, do: Date.range(Date.new!(@year, 1, 1), Date.new!(@year, 12, 31)) |> Enum.to_list()

  @spec day_key(Date.t()) :: String.t()
  def day_key(%Date{} = date), do: Date.to_iso8601(date)

  @spec load_year(keyword()) :: map()
  def load_year(opts \\ []) do
    curated_dir = curated_dir(opts)
    monthly_demand = demand_by_month(curated_dir)
    monthly_refineries = refineries_by_month(curated_dir)

    %{
      demand_by_day: demand_by_day(monthly_demand),
      refineries_by_day: refineries_by_day(monthly_refineries)
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
      {month_index(row["month"]), %{demand_m3: parse_float(row["gasolina_a_equivalent_m3"])}}
    end)
  end

  defp refineries_by_month(curated_dir) do
    monthly_yields = monthly_yields_by_id(curated_dir)
    national_average = national_average_yield(curated_dir)

    curated_dir
    |> Path.join(@refinery_capacity_file)
    |> read_csv_rows()
    |> Enum.filter(&in_catalog?/1)
    |> Enum.group_by(&month_index(&1["month"]))
    |> Map.new(fn {month, rows} ->
      {month, Enum.map(rows, &to_refinery_attrs(&1, monthly_yields, national_average))}
    end)
  end

  defp demand_by_day(monthly_demand) do
    Map.new(days(), fn date ->
      demand = Map.fetch!(monthly_demand, date.month).demand_m3 / Date.days_in_month(date)
      {date, %{demand_m3: demand}}
    end)
  end

  defp refineries_by_day(monthly_refineries) do
    Map.new(days(), fn date ->
      days_in_month = Date.days_in_month(date) * 1.0

      {date,
       Enum.map(Map.fetch!(monthly_refineries, date.month), fn refinery ->
         Map.merge(refinery, %{
           capacity_m3: refinery.capacity_m3 / days_in_month,
           processing_capacity_m3: refinery.processing_capacity_m3 / days_in_month
         })
       end)}
    end)
  end

  defp to_refinery_attrs(capacity_row, monthly_yields, national_average) do
    catalog_entry = Catalog.find(capacity_row["refinery_code"])

    %{
      id: capacity_row["refinery_code"],
      name: catalog_entry.name,
      uf: catalog_entry.uf,
      capacity_m3: 0.0,
      processing_capacity_m3: parse_float(capacity_row["capacity_m3_month"]),
      observed_monthly_yields: Map.get(monthly_yields, capacity_row["refinery_code"], []),
      national_average_yield: national_average
    }
  end

  defp national_average_yield(curated_dir) do
    values =
      curated_dir
      |> Path.join(@refinery_capacity_file)
      |> read_csv_rows()
      |> Enum.uniq_by(& &1["month"])
      |> Enum.map(&parse_float(&1["national_avg_gasoline_a_yield_used"]))

    Enum.sum(values) / length(values)
  end

  defp monthly_yields_by_id(curated_dir) do
    production_by_key =
      values_by_refinery_month(curated_dir, @production_file, "gasolina_a_m3")

    curated_dir
    |> Path.join(@refinery_capacity_file)
    |> read_csv_rows()
    |> Enum.filter(&in_catalog?/1)
    |> Enum.group_by(& &1["refinery_code"])
    |> Map.new(fn {id, rows} ->
      yields =
        Enum.flat_map(rows, fn row ->
          throughput = parse_float(row["utilized_throughput_m3"])
          production = Map.get(production_by_key, {id, row["month"]}, 0.0)

          if usable_for_yield?(production, throughput) do
            [production / throughput]
          else
            []
          end
        end)

      {id, yields}
    end)
  end

  defp values_by_refinery_month(curated_dir, file, column) do
    curated_dir
    |> Path.join(file)
    |> read_csv_rows()
    |> Map.new(fn row ->
      {{row["refinery_code"], row["month"]}, parse_float(row[column])}
    end)
  end

  defp in_catalog?(row), do: Catalog.find(row["refinery_code"]) != nil

  defp usable_for_yield?(_production, throughput) when throughput <= 0.0, do: false

  defp usable_for_yield?(production, throughput), do: production / throughput <= 1.0

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
