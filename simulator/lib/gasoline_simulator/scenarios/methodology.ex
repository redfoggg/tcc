defmodule GasolineSimulator.Scenarios.Methodology do
  alias GasolineSimulator.Data.Catalog
  alias GasolineSimulator.Data.Regions
  alias GasolineSimulator.Data.Repository
  alias GasolineSimulator.Refineries.Distances
  alias GasolineSimulator.Scenarios.Export
  alias GasolineSimulator.Models.Problem
  alias GasolineSimulator.Scenarios.Runner
  alias GasolineSimulator.Scenarios.YieldSampling

  @runs 10
  @productive_count 4
  @outage_count 2
  @outage_months 3
  @blocked_roads 3
  @corridor_weight 4
  @supply_regions [:south, :southeast]
  @short_regions [:north, :northeast]

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
      scenario("referencia", "Referência", :sample, 0.0, :all),
      scenario("choque_demanda", "Choque de demanda", :sample, 15.0, :all),
      scenario(
        "demanda_mensal",
        "Demanda mensal",
        :sample,
        0.0,
        :all,
        :fixed,
        :band,
        :open,
        :swing
      ),
      scenario("manutencao_escalonada", "Manutenção escalonada", :sample, 0.0, :staggered),
      scenario(
        "falha_alta_remessa",
        "Falha alta nas remessas",
        :sample,
        0.0,
        :all,
        :fixed,
        :high
      ),
      scenario(
        "rotas_bloqueadas",
        "Rotas bloqueadas",
        :sample,
        0.0,
        :all,
        :fixed,
        :band,
        :block
      ),
      scenario("campanha_estavel", "Campanha estável", :campaign, 0.0, :all),
      scenario("mobilidade_fut", "Mobilidade do FUT", :campaign, 0.0, :all, :mobile)
    ]
  end

  defp context do
    %{
      most_productive: most_productive(Repository.annual_gasoline_m3()),
      route_rates: Map.new(1..@runs, &{&1, road_rates(1, 5)})
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
    limits = fut_limits(scenario.fut_mode, Map.get(context, :run, 1))
    closure = road_closure(scenario.roads)
    demand = monthly_demand(scenario.demand)

    %{
      params: %{
        demand_adjustment_pct: scenario.demand_adjustment_pct,
        transit_days: "par",
        failure_pct: failure_draw(scenario.failure, context),
        demand_by_month: demand.by_month
      },
      yields: yields_for(scenario, context),
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
        note: join_note(closure.note, demand.note)
      }
    }
  end

  def run(output_dir, on_progress) do
    scenarios = scenarios()
    scenario_count = length(scenarios)

    File.mkdir_p!(output_dir)
    Export.open_manifest(output_dir)

    study_context = context()

    jobs =
      scenarios
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {scenario, index} -> jobs(scenario, index, study_context) end)

    jobs
    |> Task.async_stream(&execute/1,
      max_concurrency: length(jobs),
      ordered: true,
      timeout: :infinity
    )
    |> Stream.with_index(1)
    |> Enum.each(fn {{:ok, {job, result}}, completed} ->
      Export.append_run(output_dir, job.scenario, job.run, job.instance, result)
      on_progress.(progress(job, scenario_count, completed))
    end)

    :ok
  end

  defp jobs(scenario, index, study_context) do
    shared_yields = shared_yields(scenario)

    Enum.map(1..@runs, fn run ->
      %{
        scenario: scenario,
        index: index,
        run: run,
        instance: build(scenario, run_context(study_context, run, shared_yields))
      }
    end)
  end

  defp execute(job), do: {job, Runner.run(job.instance.params, runner_opts(job.instance))}

  defp progress(job, scenario_count, completed) do
    %{
      scenario_id: job.scenario.id,
      scenario_index: job.index,
      scenario_count: scenario_count,
      run: job.run,
      runs: @runs,
      completed: completed
    }
  end

  defp runner_opts(instance) do
    [
      min_year_ms: 0,
      yields: instance.yields,
      alive_ids: instance.alive_ids,
      burst_utilization_ratio: instance.burst,
      sustainable_utilization_ratio: instance.sustainable,
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
         failure \\ :band,
         roads \\ :open,
         demand \\ :flat
       ) do
    %{
      id: id,
      name: name,
      yield_mode: yield_mode,
      demand_adjustment_pct: demand_adjustment_pct,
      availability: availability,
      fut_mode: fut_mode,
      failure: failure,
      roads: roads,
      demand: demand
    }
  end

  defp run_context(context, run, nil), do: Map.put(context, :run, run)

  defp run_context(context, run, shared_yields) do
    context
    |> Map.put(:run, run)
    |> Map.put(:shared_yields, shared_yields)
  end

  defp shared_yields(%{fut_mode: :mobile}) do
    Repository.load_year().refineries_by_day
    |> YieldSampling.campaign()
  end

  defp shared_yields(_scenario), do: nil

  defp yields_for(_scenario, %{shared_yields: drawn}) when not is_nil(drawn), do: fn _data -> drawn end
  defp yields_for(scenario, _context), do: yield_fun(scenario.yield_mode)

  defp fut_limits(:fixed, _run) do
    %{
      burst: Problem.burst_utilization_ratio(),
      sustainable: Problem.sustainable_utilization_ratio()
    }
  end

  defp fut_limits(:mobile, run) do
    %{
      burst: Problem.burst_utilization_ratio(),
      sustainable: (84 + run) / 100
    }
  end

  defp failure_draw(:band, context), do: Map.fetch!(context.route_rates, Map.get(context, :run, 1))
  defp failure_draw(:high, _context), do: road_rates(41, 100)

  defp road_rates(min_pct, max_pct) do
    Map.new(Distances.pairs(), fn pair -> {pair, Enum.random(min_pct..max_pct)} end)
  end

  defp road_closure(:open), do: %{closed_roads: fn _day -> [] end, note: ""}

  defp road_closure(:block) do
    pairs =
      Distances.pairs()
      |> Enum.sort_by(fn pair -> -:math.pow(:rand.uniform(), 1 / road_weight(pair)) end)
      |> Enum.take(@blocked_roads)
      |> Enum.sort()
    start = Enum.random(1..11)
    months = [start, start + 1]

    %{
      closed_roads: fn day ->
        if day.month in months, do: pairs, else: []
      end,
      note: road_note(pairs, months)
    }
  end

  defp road_weight({left, right}) do
    if corridor?(Regions.of_plant(left), Regions.of_plant(right)), do: @corridor_weight, else: 1
  end

  defp corridor?(left, right) do
    (left in @supply_regions and right in @short_regions) or
      (right in @supply_regions and left in @short_regions)
  end

  defp monthly_demand(:flat), do: %{by_month: %{}, note: ""}

  defp monthly_demand(:swing) do
    by_month = Map.new(1..12, fn month -> {month, Enum.random(-1..15)} end)
    listed = Enum.map_join(1..12, " ", fn month -> "#{month}:#{by_month[month]}" end)
    %{by_month: by_month, note: "demanda #{listed}"}
  end

  defp join_note("", extra), do: extra
  defp join_note(note, ""), do: note
  defp join_note(note, extra), do: note <> " " <> extra

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
