defmodule GasolineSimulator.Scenarios.Methodology do
  alias GasolineSimulator.Data.Catalog
  alias GasolineSimulator.Data.Repository
  alias GasolineSimulator.Refineries.Distances
  alias GasolineSimulator.Scenarios.Export
  alias GasolineSimulator.Models.Overrides
  alias GasolineSimulator.Models.Problem
  alias GasolineSimulator.Scenarios.Runner
  alias GasolineSimulator.Scenarios.YieldSampling

  @runs 10
  @productive_count 4
  @outage_count 2
  @outage_months 3
  @blocked_roads 3

  def runs, do: @runs

  def scenarios do
    [
      scenario("rendimento_minimo", "Rendimento mínimo", :minimum, 0.0, :all),
      scenario(
        "paradas_produtivas",
        "Paradas das mais produtivas",
        :sample,
        0.0,
        :top_pair
      ),
      scenario("referencia", "Referência", :sample, 0.0, :all, :fixed, :none, :band),
      scenario("choque_demanda", "Choque de demanda", :sample, 15.0, :all),
      scenario("manutencao_escalonada", "Manutenção escalonada", :sample, 0.0, :staggered),
      scenario(
        "falha_alta_remessa",
        "Falha alta nas remessas",
        :sample,
        0.0,
        :all,
        :fixed,
        :none,
        :high
      ),
      scenario("remessa", "Remessa entre plantas", :sample, 0.0, :all, :fixed, :pair),
      scenario(
        "rotas_bloqueadas",
        "Rotas bloqueadas",
        :sample,
        0.0,
        :all,
        :fixed,
        :none,
        :none,
        :block
      ),
      scenario("campanha_estavel", "Campanha estável", :campaign, 0.0, :all),
      scenario("mobilidade_fut", "Mobilidade do FUT", :sample, 0.0, :all, :mobile)
    ]
  end

  defp context do
    %{most_productive: most_productive(Repository.annual_gasoline_m3())}
  end

  defp most_productive(production) do
    production
    |> Enum.sort_by(fn {id, volume} -> {-volume, id} end)
    |> Enum.take(@productive_count)
    |> Enum.map(&elem(&1, 0))
  end

  def build(scenario, context) do
    {alive_ids, availability} = availability(scenario.availability, context)
    limits = fut_limits(scenario.fut_mode)
    closure = road_closure(scenario.roads)

    %{
      params: %{
        demand_adjustment_pct: scenario.demand_adjustment_pct,
        transit_days: manifest_transit(scenario.transit),
        failure_pct: failure_draw(scenario.failure)
      },
      transit: runner_transit(scenario.transit),
      yields: yield_fun(scenario.yield_mode),
      alive_ids: alive_ids,
      burst: limits.burst,
      sustainable: limits.sustainable,
      closed_roads: closure.closed_roads,
      meta: %{
        yield_mode: Atom.to_string(scenario.yield_mode),
        availability: availability.label,
        offline_refineries: availability.offline_refineries,
        offline_months: availability.offline_months,
        fut_lock: limits.sustainable,
        note: closure.note
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
      alive_ids: instance.alive_ids,
      burst_utilization_ratio: instance.burst,
      sustainable_utilization_ratio: instance.sustainable,
      transit: instance.transit,
      closed_roads: instance.closed_roads
    ]
  end

  defp scenario(
         id,
         name,
         yield_mode,
         demand_adjustment_pct,
         availability,
         fut_mode \\ :fixed,
         transit \\ :none,
         failure \\ :none,
         roads \\ :open
       ) do
    %{
      id: id,
      name: name,
      yield_mode: yield_mode,
      demand_adjustment_pct: demand_adjustment_pct,
      availability: availability,
      fut_mode: fut_mode,
      transit: transit,
      failure: failure,
      roads: roads
    }
  end

  defp manifest_transit(:pair), do: "par"
  defp manifest_transit(:none), do: Overrides.min_transit_days()

  defp runner_transit(:pair), do: :pair
  defp runner_transit(:none), do: {:fixed, Overrides.min_transit_days()}

  defp fut_limits(:fixed) do
    %{
      burst: Problem.burst_utilization_ratio(),
      sustainable: Problem.sustainable_utilization_ratio()
    }
  end

  defp fut_limits(:mobile) do
    %{
      burst: Problem.burst_utilization_ratio(),
      sustainable: Enum.random([0.92, 0.93, 0.94])
    }
  end

  defp failure_draw(:none), do: %{}
  defp failure_draw(:band), do: road_rates(1, 5)
  defp failure_draw(:high), do: road_rates(41, 100)

  defp road_rates(min_pct, max_pct) do
    Map.new(Distances.pairs(), fn pair -> {pair, Enum.random(min_pct..max_pct)} end)
  end

  defp road_closure(:open), do: %{closed_roads: fn _day -> [] end, note: ""}

  defp road_closure(:block) do
    pairs = Distances.pairs() |> Enum.take_random(@blocked_roads) |> Enum.sort()
    start = Enum.random(1..11)
    months = [start, start + 1]

    %{
      closed_roads: fn day ->
        if day.month in months, do: pairs, else: []
      end,
      note: road_note(pairs, months)
    }
  end

  defp road_note(pairs, months) do
    listed = Enum.map_join(pairs, " ", &Distances.pair_key/1)
    "rotas #{listed} meses #{Enum.join(months, "|")}"
  end

  defp yield_fun(:sample), do: &YieldSampling.draw/1
  defp yield_fun(:campaign), do: &YieldSampling.campaign/1
  defp yield_fun(:minimum), do: fn data -> YieldSampling.bound(data, :min) end

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
