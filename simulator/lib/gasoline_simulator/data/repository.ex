defmodule GasolineSimulator.Data.Repository do
  alias GasolineSimulator.Data.Catalog

  @year 2025
  @refinery_capacity_file "anp_2025_refinery_capacity_monthly.csv"
  @demand_proxy_file "anp_2025_demand_proxy_national_monthly.csv"
  @production_file "anp_2025_gasoline_a_production_by_refinery_monthly.csv"
  @max_plausible_observed_yield 0.40

  @spec days() :: [Date.t()]
  def days, do: Date.range(Date.new!(@year, 1, 1), Date.new!(@year, 12, 31)) |> Enum.to_list()

  @spec day_key(Date.t()) :: String.t()
  def day_key(%Date{} = date), do: Date.to_iso8601(date)

  @spec month_key(1..12) :: String.t()
  def month_key(month) when month in 1..12,
    do: "#{@year}-" <> String.pad_leading(Integer.to_string(month), 2, "0")

  @spec month_key(Date.t()) :: String.t()
  def month_key(%Date{} = date), do: month_key(date.month)

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
    observed_yields = observed_yields_by_id(curated_dir)

    curated_dir
    |> Path.join(@refinery_capacity_file)
    |> read_csv_rows()
    |> Enum.group_by(&month_index(&1["month"]))
    |> Map.new(fn {month, rows} ->
      {month, Enum.map(rows, &to_refinery_attrs(&1, observed_yields))}
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

  defp to_refinery_attrs(capacity_row, observed_yields) do
    catalog_entry = Catalog.find(capacity_row["refinery_code"])

    %{
      id: capacity_row["refinery_code"],
      name: catalog_entry.name,
      uf: catalog_entry.uf,
      capacity_m3: parse_float(capacity_row["capacity_gasoline_a_m3_month"]),
      processing_capacity_m3: parse_float(capacity_row["capacity_m3_month"]),
      observed_yield: Map.get(observed_yields, capacity_row["refinery_code"])
    }
  end

  defp observed_yields_by_id(curated_dir) do
    throughput_by_id =
      sum_by_refinery(curated_dir, @refinery_capacity_file, "utilized_throughput_m3")

    production_by_id = sum_by_refinery(curated_dir, @production_file, "gasolina_a_m3")

    Map.new(throughput_by_id, fn {id, throughput} ->
      production = Map.get(production_by_id, id, 0.0)
      {id, observed_yield(production, throughput)}
    end)
  end

  defp sum_by_refinery(curated_dir, file, column) do
    curated_dir
    |> Path.join(file)
    |> read_csv_rows()
    |> Enum.group_by(& &1["refinery_code"])
    |> Map.new(fn {id, rows} ->
      {id, Enum.sum(Enum.map(rows, &parse_float(&1[column])))}
    end)
  end

  defp observed_yield(_production, throughput) when throughput <= 0.0, do: nil

  defp observed_yield(production, throughput) do
    yield = production / throughput

    if yield > 0.0 and yield <= @max_plausible_observed_yield do
      yield
    end
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
