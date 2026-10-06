defmodule GasolineSimulator.Scenarios.Methodology do
  alias GasolineSimulator.Data.Catalog
  alias GasolineSimulator.Data.Repository
  alias GasolineSimulator.Scenarios.Export
  alias GasolineSimulator.Scenarios.Runner
  alias GasolineSimulator.Scenarios.YieldSampling

  @runs 10
  @productive_count 4
  @outage_count 2
  @outage_months 3
  @opening_days 15
  @regions [
    {"sao_paulo", ["REPLAN", "REVAP", "RPBC", "RECAP"]},
    {"sul", ["REPAR", "REFAP"]},
    {"nordeste", ["REFMAT", "RNEST", "RPCC"]},
    {"rio_minas", ["REDUC", "REGAP"]}
  ]

  def runs, do: @runs

  def scenarios do
    [
      scenario("rendimento_minimo", "Rendimento mínimo", :minimum, 0.0, :zero, :all),
      scenario(
        "paradas_produtivas",
        "Paradas das mais produtivas",
        :sample,
        0.0,
        :zero,
        :top_pair
      ),
      scenario("rendimento_maximo", "Rendimento máximo", :maximum, 0.0, :zero, :all),
      scenario("referencia", "Referência", :sample, 0.0, :zero, :all),
      scenario("choque_demanda", "Choque de demanda", :sample, 15.0, :zero, :all),
      scenario("demanda_retraida", "Demanda retraída", :sample, -15.0, :zero, :all),
      scenario("manutencao_escalonada", "Manutenção escalonada", :sample, 0.0, :zero, :staggered),
      scenario("cluster_regional", "Cluster regional", :sample, 0.0, :zero, :region),
      scenario("estoque_de_abertura", "Estoque de abertura", :sample, 0.0, :fifteen_days, :all),
      scenario("campanha_estavel", "Campanha estável", :campaign, 0.0, :zero, :all)
    ]
  end

  defp context do
    year_data = Repository.load_year()
    demands = Enum.map(year_data.demand_by_day, fn {_day, row} -> row.demand_m3 end)

    %{
      most_productive: most_productive(Repository.annual_gasoline_m3()),
      mean_daily_demand_m3: Enum.sum(demands) / length(demands)
    }
  end

  defp most_productive(production) do
    production
    |> Enum.sort_by(fn {id, volume} -> {-volume, id} end)
    |> Enum.take(@productive_count)
    |> Enum.map(&elem(&1, 0))
  end

  def build(scenario, context) do
    {alive_ids, availability} = availability(scenario.availability, context)

    %{
      params: %{
        initial_inventory_m3: inventory(scenario.inventory, context),
        demand_adjustment_pct: scenario.demand_adjustment_pct
      },
      yields: yield_fun(scenario.yield_mode),
      alive_ids: alive_ids,
      meta: %{
        yield_mode: Atom.to_string(scenario.yield_mode),
        availability: availability.label,
        offline_refineries: availability.offline_refineries,
        offline_months: availability.offline_months
      }
    }
  end

  def run(output_dir, on_progress) do
    study_context = context()
    scenarios = scenarios()

    File.mkdir_p!(output_dir)
    Export.open_manifest(output_dir)

    scenarios
    |> Enum.with_index(1)
    |> Enum.each(fn {scenario, index} ->
      run_scenario(scenario, index, length(scenarios), study_context, output_dir, on_progress)
    end)

    :ok
  end

  defp run_scenario(scenario, index, scenario_count, study_context, output_dir, on_progress) do
    Enum.each(1..@runs, fn run ->
      on_progress.(%{
        scenario_id: scenario.id,
        scenario_index: index,
        scenario_count: scenario_count,
        run: run,
        runs: @runs,
        completed: (index - 1) * @runs + (run - 1)
      })

      instance = build(scenario, study_context)
      result = Runner.run(instance.params, runner_opts(instance))
      Export.append_run(output_dir, scenario, run, instance, result)
    end)
  end

  defp runner_opts(instance) do
    [
      min_year_ms: 0,
      yields: instance.yields,
      alive_ids: instance.alive_ids
    ]
  end

  defp scenario(id, name, yield_mode, demand_adjustment_pct, inventory, availability) do
    %{
      id: id,
      name: name,
      yield_mode: yield_mode,
      demand_adjustment_pct: demand_adjustment_pct,
      inventory: inventory,
      availability: availability
    }
  end

  defp yield_fun(:sample), do: &YieldSampling.draw/1
  defp yield_fun(:campaign), do: &YieldSampling.campaign/1
  defp yield_fun(:minimum), do: fn data -> YieldSampling.bound(data, :min) end
  defp yield_fun(:maximum), do: fn data -> YieldSampling.bound(data, :max) end

  defp inventory(:zero, _context), do: 0.0

  defp inventory(:fifteen_days, context), do: @opening_days * context.mean_daily_demand_m3

  defp availability(:all, _context) do
    {fn _day -> Catalog.ids() end, blank_availability("all")}
  end

  defp availability(:top_pair, context) do
    ids = context.most_productive |> Enum.take_random(@outage_count) |> Enum.sort()
    start = Enum.random(1..(13 - @outage_months))
    months = Enum.to_list(start..(start + @outage_months - 1))

    {month_block(ids, months),
     %{
       label: "top_pair",
       offline_refineries: Enum.join(ids, "|"),
       offline_months: Enum.join(months, "|")
     }}
  end

  defp availability(:staggered, _context) do
    assignment =
      Catalog.ids()
      |> Enum.shuffle()
      |> Enum.with_index(1)

    by_month = Map.new(assignment, fn {id, month} -> {month, id} end)

    label =
      assignment
      |> Enum.sort_by(&elem(&1, 1))
      |> Enum.map_join("|", fn {id, month} -> "#{month}:#{id}" end)

    alive_ids = fn day ->
      offline = Map.fetch!(by_month, day.month)
      Enum.reject(Catalog.ids(), &(&1 == offline))
    end

    {alive_ids,
     %{
       label: "staggered",
       offline_refineries: label,
       offline_months: "1|2|3|4|5|6|7|8|9|10|11|12"
     }}
  end

  defp availability(:region, _context) do
    {region, ids} = Enum.random(@regions)
    ids = Enum.sort(ids)
    start = Enum.random(1..11)
    months = [start, start + 1]

    {month_block(ids, months),
     %{
       label: "region:#{region}",
       offline_refineries: Enum.join(ids, "|"),
       offline_months: Enum.join(months, "|")
     }}
  end

  defp month_block(ids, months) do
    offline = MapSet.new(ids)

    fn day ->
      if day.month in months do
        Enum.reject(Catalog.ids(), &MapSet.member?(offline, &1))
      else
        Catalog.ids()
      end
    end
  end

  defp blank_availability(label) do
    %{label: label, offline_refineries: "", offline_months: ""}
  end
end
