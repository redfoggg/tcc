defmodule GasolineSimulator.Scenarios.Export do
  alias GasolineSimulator.Data.Catalog

  @manifest [
    :scenario_id,
    :scenario_name,
    :run,
    :status,
    :yield_mode,
    :demand_adjustment_pct,
    :initial_inventory_m3,
    :availability,
    :offline_refineries,
    :offline_months,
    :annual_demand_m3,
    :annual_production_m3,
    :annual_deficit_m3,
    :annual_served_demand_m3,
    :annual_fut_pct,
    :annual_coverage,
    :ending_inventory_m3,
    :csv_path,
    :note
  ]

  @detail [
    :scenario_id,
    :run,
    :date,
    :refinery_id,
    :uf,
    :in_model,
    :simulated_yield,
    :allocated_m3,
    :petroleum_processed_m3,
    :processing_capacity_m3,
    :fut_pct,
    :active,
    :day_demand_m3,
    :day_production_m3,
    :day_deficit_m3,
    :day_starting_inventory_m3,
    :day_ending_inventory_m3,
    :day_total_fut_pct
  ]

  def open_manifest(output_dir) do
    File.write!(manifest_path(output_dir), line(@manifest))
  end

  def append_run(output_dir, scenario, run, instance, {:ok, result}) do
    relative = detail_relative(scenario.id, run)
    write_detail(output_dir, relative, scenario, run, result)
    append_manifest(output_dir, manifest_ok(scenario, run, instance, result, relative))
  end

  def append_run(output_dir, scenario, run, instance, {:error, reason}) do
    append_manifest(output_dir, manifest_failed(scenario, run, instance, reason))
  end

  defp write_detail(output_dir, relative, scenario, run, result) do
    path = Path.join(output_dir, relative)
    File.mkdir_p!(Path.dirname(path))
    yields = result.simulated_yields

    rows =
      result.days
      |> Enum.flat_map(&day_rows(scenario, run, &1, yields))
      |> Enum.map(&line(@detail, &1))

    File.write!(path, [line(@detail) | rows])
  end

  defp day_rows(scenario, run, day, yields) do
    by_id = Map.new(day.refineries, &{&1.id, &1})
    day_yields = yields_for(yields, day.month)

    Enum.map(Catalog.ids(), fn id ->
      case Map.get(by_id, id) do
        nil -> offline_row(scenario, run, day, id, Map.get(day_yields, id))
        refinery -> online_row(scenario, run, day, refinery)
      end
    end)
  end

  defp yields_for(yields, date) do
    Map.fetch!(yields, Date.from_iso8601!(date))
  end

  defp online_row(scenario, run, day, refinery) do
    shared_row(scenario, run, day)
    |> Map.merge(%{
      refinery_id: refinery.id,
      uf: refinery.uf,
      in_model: 1,
      simulated_yield: refinery.simulated_yield,
      allocated_m3: refinery.allocated_m3,
      petroleum_processed_m3: refinery.petroleum_processed_m3,
      processing_capacity_m3: refinery.processing_capacity_m3,
      fut_pct: refinery.fut_pct,
      active: flag(refinery.active)
    })
  end

  defp offline_row(scenario, run, day, id, yield) do
    shared_row(scenario, run, day)
    |> Map.merge(%{
      refinery_id: id,
      uf: Catalog.find(id).uf,
      in_model: 0,
      simulated_yield: yield,
      allocated_m3: 0.0,
      petroleum_processed_m3: 0.0,
      processing_capacity_m3: nil,
      fut_pct: nil,
      active: 0
    })
  end

  defp shared_row(scenario, run, day) do
    %{
      scenario_id: scenario.id,
      run: run,
      date: day.month,
      day_demand_m3: day.demand_m3,
      day_production_m3: day.production_m3,
      day_deficit_m3: day.deficit_m3,
      day_starting_inventory_m3: day.starting_inventory_m3,
      day_ending_inventory_m3: day.ending_inventory_m3,
      day_total_fut_pct: day.total_fut_pct
    }
  end

  defp manifest_ok(scenario, run, instance, result, relative) do
    annual = result.annual

    base_manifest(scenario, run, instance)
    |> Map.merge(%{
      status: "ok",
      annual_demand_m3: annual.demand_m3,
      annual_production_m3: annual.production_m3,
      annual_deficit_m3: annual.deficit_m3,
      annual_served_demand_m3: annual.served_demand_m3,
      annual_fut_pct: annual.total_fut_pct,
      annual_coverage: annual.coverage,
      ending_inventory_m3: annual.ending_inventory_m3,
      csv_path: relative,
      note: ""
    })
  end

  defp manifest_failed(scenario, run, instance, reason) do
    base_manifest(scenario, run, instance)
    |> Map.merge(%{
      status: "failed",
      annual_demand_m3: nil,
      annual_production_m3: nil,
      annual_deficit_m3: nil,
      annual_served_demand_m3: nil,
      annual_fut_pct: nil,
      annual_coverage: nil,
      ending_inventory_m3: nil,
      csv_path: "",
      note: failure_note(reason)
    })
  end

  defp base_manifest(scenario, run, instance) do
    %{
      scenario_id: scenario.id,
      scenario_name: scenario.name,
      run: run,
      yield_mode: instance.meta.yield_mode,
      demand_adjustment_pct: instance.params.demand_adjustment_pct,
      initial_inventory_m3: instance.params.initial_inventory_m3,
      availability: instance.meta.availability,
      offline_refineries: instance.meta.offline_refineries,
      offline_months: instance.meta.offline_months
    }
  end

  defp failure_note(%{month: month, reason: reason}) do
    "#{month}: #{reason}"
  end

  defp append_manifest(output_dir, row) do
    File.write!(manifest_path(output_dir), line(@manifest, row), [:append])
  end

  defp manifest_path(output_dir), do: Path.join(output_dir, "manifest.csv")

  defp detail_relative(scenario_id, run) do
    Path.join(scenario_id, "run_#{pad(run)}.csv")
  end

  defp pad(run), do: run |> Integer.to_string() |> String.pad_leading(2, "0")

  defp flag(true), do: 1
  defp flag(false), do: 0

  defp line(columns), do: [Enum.join(columns, ","), "\n"]

  defp line(columns, row) do
    columns
    |> Enum.map(&cell(Map.get(row, &1)))
    |> Enum.join(",")
    |> Kernel.<>("\n")
  end

  defp cell(nil), do: ""
  defp cell(value) when is_integer(value), do: Integer.to_string(value)

  defp cell(value) when is_float(value),
    do: :erlang.float_to_binary(value, [:compact, decimals: 8])

  defp cell(value) when is_binary(value) do
    if String.contains?(value, [",", "\"", "\n"]) do
      "\"" <> String.replace(value, "\"", "\"\"") <> "\""
    else
      value
    end
  end
end
