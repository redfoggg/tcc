defmodule GasolineSimulatorWeb.DashboardLive do
  use GasolineSimulatorWeb, :live_view

  alias GasolineSimulator.Data.Catalog
  alias GasolineSimulator.Data.Historical
  alias GasolineSimulator.Refineries.Plant
  alias GasolineSimulator.Scenarios.Orchestrator
  alias GasolineSimulator.Scenarios.Study

  @visible_delivery_groups 5

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Orchestrator.subscribe()
      Study.subscribe()
    end

    socket =
      socket
      |> assign(
        page_title: "Painel de alocação de gasolina A",
        historical: Historical.load(),
        demand_adjustment_pct: nil,
        failure_pct: %{},
        planned_run: nil,
        plants: Orchestrator.plant_statuses(),
        deliveries: Orchestrator.deliveries(),
        deliveries_expanded: false,
        study: Study.status()
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("run_plan", params, socket) do
    demand_adjustment_pct = params |> Map.get("demand_adjustment_pct") |> parse_float_input()
    failure_pct = params |> Map.get("failure_pct", %{}) |> Plant.failure_pct()

    controls = %{
      demand_adjustment_pct: demand_adjustment_pct,
      failure_pct: failure_pct
    }

    {:ok, planned_run} = Orchestrator.run_plan(controls)

    {:noreply,
     assign(socket,
       planned_run: planned_run,
       demand_adjustment_pct: demand_adjustment_pct,
       failure_pct: failure_pct
     )}
  end

  @impl true
  def handle_event("disconnect_plant", %{"id" => id}, socket) do
    Orchestrator.disconnect_plant(id)
    {:noreply, socket}
  end

  def handle_event("reconnect_plant", %{"id" => id}, socket) do
    Orchestrator.reconnect_plant(id)
    {:noreply, socket}
  end

  def handle_event("toggle_deliveries", _params, socket) do
    {:noreply, assign(socket, deliveries_expanded: not socket.assigns.deliveries_expanded)}
  end

  def handle_event("run_study", _params, socket) do
    case Study.start() do
      {:ok, study} -> {:noreply, assign(socket, study: study)}
      {:error, :already_running} -> {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:plan_updated, %{id: id} = planned_run}, socket) do
    case socket.assigns.planned_run do
      %{id: ^id} ->
        {:noreply,
         assign(socket, planned_run: planned_run, deliveries: Orchestrator.deliveries())}

      _other ->
        {:noreply, socket}
    end
  end

  def handle_info({:plants_updated, plants}, socket) do
    {:noreply, assign(socket, plants: plants, deliveries: Orchestrator.deliveries())}
  end

  def handle_info({:study_updated, study}, socket) do
    {:noreply, assign(socket, study: study)}
  end

  defp parse_float_input(nil), do: nil
  defp parse_float_input(""), do: nil

  defp parse_float_input(value) do
    {number, ""} = Float.parse(value)
    number
  end

  defp fmt(value, divisor \\ 1, places \\ 1) do
    :erlang.float_to_binary(value / divisor * 1.0, decimals: places)
  end

  defp annual_volume(value), do: fmt(value, 1_000_000, 2)
  defp monthly_volume(value), do: fmt(value, 1_000, 1)

  defp pct(value), do: fmt(value * 100.0)
  defp fut_pct(value), do: fmt(value)

  defp region_name(:north), do: "Norte"
  defp region_name(:northeast), do: "Nordeste"
  defp region_name(:southeast), do: "Sudeste"
  defp region_name(:south), do: "Sul"

  defp operating_pct(%{up: false}), do: "0.0%"
  defp operating_pct(%{fut_pct: nil}), do: "n/d"
  defp operating_pct(%{fut_pct: value}), do: "#{fut_pct(value)}%"

  defp produced_m3(plant), do: cubic_m3(plant.produced_m3)
  defp stock_m3(plant), do: cubic_m3(plant.stock_m3)
  defp cubic_m3(nil), do: "n/d m³"
  defp cubic_m3(value), do: "#{fmt(value, 1, 0)} m³"

  defp plant_stock_sum(plants), do: Enum.sum_by(plants, &(&1.stock_m3 || 0.0))

  defp signed(value, formatter) when value > 0, do: "+#{formatter.(value)}"
  defp signed(value, formatter), do: formatter.(value)

  defp annual_of(%{result: %{annual: annual}}), do: annual
  defp annual_of(_other), do: nil

  defp months_of(%{result: %{months: months}}), do: months
  defp months_of(_other), do: []

  defp balance_info(value) when value > 0, do: {"superávit", "text-success"}
  defp balance_info(value) when value < 0, do: {"déficit", "text-error"}
  defp balance_info(_value), do: {"equilibrado", "text-base-content"}

  defp study_status(%{status: :running} = study) do
    name = study.scenario_id || "preparando"

    "Em execução: cenário #{study.scenario_index} de #{study.scenario_count}, execução #{study.run} de #{study.runs} (#{name})."
  end

  defp study_status(%{status: :completed}), do: "Concluída. Os CSV estão na pasta abaixo."
  defp study_status(%{status: :failed} = study), do: "A bateria falhou: #{study.error}"
  defp study_status(_study), do: "Ainda não executada."

  defp plan_status(:running), do: "em execução"
  defp plan_status(:completed), do: "concluído"
  defp plan_status(:failed), do: "falhou"
  defp plan_status(status), do: to_string(status)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} wide>
      <div class="w-full space-y-10">
        <div class="max-w-4xl space-y-2">
          <h1 class="text-3xl font-bold tracking-tight">Painel de alocação de gasolina A</h1>
          <p class="text-base leading-6 opacity-70">
            O Histórico 2025 mostra o ano observado, já curado. O Planejado 2025
            simula os 365 dias: um plano central decide o petróleo de cada
            refinaria, o rendimento sorteado transforma esse petróleo em gasolina
            A e comboios de caminhão levam a sobra das regiões que refinam mais
            para as que refinam menos. Cada comboio leva até 30 m³, só sai com
            pelo menos 20 m³ e só cobre a demanda no dia em que chega. São 12
            refinarias. A LUBNOR fica de fora porque não produz gasolina A.
            Derrubar uma planta tira o processo dela do ar, e o plano
            redistribui a demanda até ela ser recuperada. FUT é o fator de
            utilização total: a fração da capacidade ocupada pela destilação.
            O ano leva pelo menos 30 s.
          </p>
        </div>

        <div class="grid items-start gap-8 2xl:grid-cols-2">
          <.historical_panel historical={@historical} />
          <.planned_panel planned_run={@planned_run} />
        </div>

        <.plants_panel plants={@plants} />
        <.deliveries_panel deliveries={@deliveries} expanded={@deliveries_expanded} />

        <form phx-submit="run_plan" id="dashboard-planning-form" class="rounded border p-4 space-y-4">
          <h2 class="font-semibold">Controles do Planejado 2025</h2>

          <div class="grid gap-4 sm:grid-cols-2">
            <div>
              <label for="dashboard-demand-adjustment" class="text-sm font-medium">
                Ajuste de demanda (%, opcional)
              </label>
              <input
                type="number"
                step="any"
                name="demand_adjustment_pct"
                id="dashboard-demand-adjustment"
                value={@demand_adjustment_pct}
                class="input input-bordered"
              />
            </div>
          </div>

          <div class="space-y-2">
            <h3 class="text-sm font-medium">Dificuldade logística por destino (%)</h3>
            <p class="text-sm opacity-70">
              O número vale para as entregas que vão para aquela refinaria.
              O campo começa em 1. 0 mantém a remessa. 100 faz toda entrega para ela falhar e a carga se perde.
              Depois de {Plant.consecutive_loss_limit()} perdas seguidas na mesma rota,
              a origem espera {Plant.route_pause_days()} dias antes de tentar de novo.
            </p>
            <div class="grid gap-3 sm:grid-cols-3 lg:grid-cols-4">
              <div :for={id <- Catalog.ids()}>
                <label for={"dashboard-failure-#{id}"} class="text-sm font-medium">{id}</label>
                <input
                  type="number"
                  step="1"
                  min="0"
                  max="100"
                  name={"failure_pct[#{id}]"}
                  id={"dashboard-failure-#{id}"}
                  value={Map.get(@failure_pct, id, Plant.default_failure_pct())}
                  class="input input-bordered w-full"
                />
              </div>
            </div>
          </div>

          <.button id="dashboard-run-plan">Executar Planejado 2025</.button>
        </form>

        <section id="dashboard-study" class="rounded border p-4 space-y-3">
          <h2 class="font-semibold">Bateria metodológica</h2>
          <p class="text-sm opacity-70">
            Dez cenários, dez execuções cada. O botão grava um CSV por
            execução em data/studies. As plantas deste painel permanecem
            como estão. Cada cenário traz a própria demanda. Toda remessa usa
            o tempo de caminhão de cada par. O ajuste de demanda e a
            porcentagem de falha do formulário não
            entram na bateria. A referência sorteia de 1% a 5% de falha em
            cada rota. A falha alta sorteia de 41% a 100%. Os demais cenários
            deixam a porcentagem em 1.
          </p>
          <p id="dashboard-study-status" class="text-sm">{study_status(@study)}</p>
          <p
            :if={@study.output_dir}
            id="dashboard-study-path"
            class="text-sm font-mono break-all"
          >
            {@study.output_dir}
          </p>
          <.button
            id="dashboard-run-study"
            phx-click="run_study"
            disabled={@study.status == :running}
          >
            Rodar bateria
          </.button>
        </section>
      </div>
    </Layouts.app>
    """
  end

  attr :plants, :list, required: true

  defp plants_panel(assigns) do
    ~H"""
    <div id="dashboard-plants" class="rounded border p-4 space-y-3">
      <h2 class="font-semibold">Refinarias no ar</h2>
      <p class="text-sm opacity-70">
        Cada item é o processo de uma refinaria. Planta ausente não entra
        no plano do dia. Ao recuperar, o piso dela começa em 40% e sobe 1
        ponto percentual por dia sem déficit no país, até 94%. O FUT, a
        gasolina A acumulada e o estoque atualizam a cada dia do Planejado.
        O estoque é o tanque da planta no fim do dia e não inclui o que
        está na estrada.
      </p>
      <p id="dashboard-plant-stock-sum" class="text-sm font-mono tabular-nums">
        Soma nas plantas {fmt(plant_stock_sum(@plants), 1, 0)} m³
      </p>
      <div class="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
        <div
          :for={plant <- @plants}
          id={"dashboard-plant-#{plant.id}"}
          class="flex items-start justify-between gap-3 rounded border px-3 py-3"
        >
          <div class="min-w-0 space-y-1">
            <p class="font-medium">{plant.id}</p>
            <p class="text-xs opacity-60">
              {plant.uf} · {if(plant.up, do: "no ar", else: "ausente")}
            </p>
            <p id={"dashboard-plant-fut-#{plant.id}"} class="text-sm font-mono tabular-nums">
              Operando {operating_pct(plant)}
            </p>
            <p id={"dashboard-plant-produced-#{plant.id}"} class="text-sm font-mono tabular-nums">
              Produzido {produced_m3(plant)}
            </p>
            <p id={"dashboard-plant-stock-#{plant.id}"} class="text-sm font-mono tabular-nums">
              Estoque {stock_m3(plant)}
            </p>
          </div>
          <button
            :if={plant.up}
            type="button"
            id={"dashboard-disconnect-#{plant.id}"}
            phx-click="disconnect_plant"
            phx-value-id={plant.id}
            class="btn btn-sm"
          >
            Derrubar
          </button>
          <button
            :if={not plant.up}
            type="button"
            id={"dashboard-reconnect-#{plant.id}"}
            phx-click="reconnect_plant"
            phx-value-id={plant.id}
            class="btn btn-sm"
          >
            Recuperar
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :deliveries, :list, required: true
  attr :expanded, :boolean, required: true

  defp deliveries_panel(assigns) do
    groups = delivery_groups(assigns.deliveries)

    visible_groups =
      if assigns.expanded, do: groups, else: Enum.take(groups, @visible_delivery_groups)

    assigns =
      assign(assigns,
        visible_groups: visible_groups,
        more_groups?: length(groups) > @visible_delivery_groups,
        summary: delivery_summary(groups, length(assigns.deliveries))
      )

    ~H"""
    <div id="dashboard-deliveries" class="rounded border p-4 space-y-3">
      <h2 class="font-semibold">Entregas a caminho</h2>
      <p class="text-sm opacity-70">
        Cada entrega é um processo a caminho. A falha logística acontece na
        saída, pela porcentagem do destino. A carga perdida não aparece aqui.
        Origem e destino são avisados e o volume some. Comboios da mesma
        origem e destino ficam no mesmo card.
      </p>
      <p :if={@deliveries == []} class="text-sm opacity-60">Nenhuma entrega a caminho.</p>
      <div :if={@deliveries != []} class="space-y-3">
        <p id="dashboard-deliveries-summary" class="text-sm opacity-60">{@summary}</p>
        <div class="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
          <div
            :for={group <- @visible_groups}
            id={"dashboard-delivery-#{group.origin_id}-#{group.destination_id}"}
            class="rounded border px-3 py-3"
          >
            <div class="min-w-0 space-y-1">
              <p class="font-medium">{group.origin_id} → {group.destination_id}</p>
              <p class="text-xs opacity-60">
                {convoy_label(group.count)} · {arrival_label(group)}
              </p>
              <p class="text-sm font-mono tabular-nums">{fmt(group.volume_m3, 1, 1)} m³</p>
            </div>
          </div>
        </div>
        <button
          :if={@more_groups?}
          type="button"
          id="dashboard-deliveries-toggle"
          phx-click="toggle_deliveries"
          class="btn btn-sm"
        >
          {deliveries_toggle_label(@expanded)}
        </button>
      </div>
    </div>
    """
  end

  defp delivery_groups(deliveries) do
    deliveries
    |> Enum.group_by(&{&1.origin_id, &1.destination_id})
    |> Enum.map(fn {{origin_id, destination_id}, items} ->
      arrivals = Enum.sort(Enum.map(items, & &1.arrival), Date)

      %{
        origin_id: origin_id,
        destination_id: destination_id,
        count: length(items),
        volume_m3: Enum.sum_by(items, & &1.volume_m3),
        first_arrival: List.first(arrivals),
        last_arrival: List.last(arrivals)
      }
    end)
    |> Enum.sort_by(&{&1.first_arrival, &1.origin_id, &1.destination_id})
  end

  defp delivery_summary(groups, convoys) do
    "#{route_label(length(groups))}, #{convoy_label(convoys)}"
  end

  defp route_label(1), do: "1 rota"
  defp route_label(count), do: "#{count} rotas"

  defp convoy_label(1), do: "1 comboio"
  defp convoy_label(count), do: "#{count} comboios"

  defp arrival_label(%{first_arrival: day, last_arrival: day}), do: "Chega em #{day}"

  defp arrival_label(%{first_arrival: first, last_arrival: last}) do
    "Chega de #{first} a #{last}"
  end

  defp deliveries_toggle_label(true), do: "Ver menos"
  defp deliveries_toggle_label(false), do: "Ver mais"

  attr :historical, :map, required: true

  defp historical_panel(assigns) do
    {balance_label, balance_class} = balance_info(assigns.historical.annual.balance_m3)
    assigns = assign(assigns, balance_label: balance_label, balance_class: balance_class)

    ~H"""
    <section
      class="min-w-0 rounded-xl border border-base-300 bg-base-100 shadow-sm"
      id="dashboard-historical-panel"
    >
      <div class="space-y-2 border-b border-base-300 px-6 py-5">
        <h2 class="text-xl font-semibold">Histórico 2025</h2>
        <p class="text-sm leading-5 opacity-70">
          Artefato curado estático das 12 refinarias do catálogo. LUBNOR
          não entra: não produz gasolina A. O FUT Total usa a carga de
          destilação atmosférica observada (petróleo e outras cargas)
          sobre a capacidade bruta.
        </p>
      </div>
      <div class="grid gap-x-10 gap-y-4 border-b border-base-300 px-6 py-6 sm:grid-cols-2">
        <.metric
          label="Produção fornecida"
          value={annual_volume(@historical.annual.production_supplied_m3)}
          unit="Mm³"
        />
        <.metric
          label="Demanda-alvo"
          value={annual_volume(@historical.annual.demand_target_m3)}
          unit="Mm³"
        />
        <.metric
          label="Saldo assinado"
          value={signed(@historical.annual.balance_m3, &annual_volume/1)}
          unit={"Mm³ · #{@balance_label}"}
          value_class={@balance_class}
        />
        <.metric
          label="FUT Total"
          value={"#{fut_pct(@historical.annual.total_fut_pct)}%"}
          unit="razão de somas"
        />
      </div>
      <div class="space-y-3 px-6 py-5">
        <h3 class="text-sm font-semibold uppercase tracking-wide opacity-60">
          Volumes mensais · 10³ m³
        </h3>
        <div class="overflow-x-auto">
          <table class="w-full min-w-[42rem] text-sm">
            <thead>
              <tr class="border-b border-base-300 text-left text-xs uppercase tracking-wide opacity-60">
                <th class="py-3 pr-4 font-medium">Mês</th>
                <th class="px-3 py-3 text-right font-medium">Produção fornecida</th>
                <th class="px-3 py-3 text-right font-medium">Demanda-alvo</th>
                <th class="px-3 py-3 text-right font-medium">Saldo assinado</th>
                <th class="py-3 pl-3 text-right font-medium">FUT Total</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-base-200">
              <tr :for={month <- @historical.months} class="hover:bg-base-200/50">
                <td class="py-3 pr-4 font-medium whitespace-nowrap">{month.month}</td>
                <td class="px-3 py-3 text-right font-mono tabular-nums">
                  {monthly_volume(month.production_supplied_m3)}
                </td>
                <td class="px-3 py-3 text-right font-mono tabular-nums">
                  {monthly_volume(month.demand_target_m3)}
                </td>
                <td class={[
                  "px-3 py-3 text-right font-mono tabular-nums",
                  elem(balance_info(month.balance_m3), 1)
                ]}>
                  {signed(month.balance_m3, &monthly_volume/1)}
                </td>
                <td class="py-3 pl-3 text-right font-mono tabular-nums">
                  {fut_pct(month.total_fut_pct)}%
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </section>
    """
  end

  attr :planned_run, :map, required: true

  defp planned_panel(assigns) do
    annual = annual_of(assigns.planned_run)
    months = months_of(assigns.planned_run)

    {balance_label, balance_class} =
      if annual, do: balance_info(annual.balance_m3), else: {nil, nil}

    assigns =
      assign(assigns,
        annual: annual,
        months: months,
        balance_label: balance_label,
        balance_class: balance_class
      )

    ~H"""
    <section
      class="min-w-0 rounded-xl border border-base-300 bg-base-100 shadow-sm"
      id="dashboard-planned-panel"
    >
      <div class="flex items-center justify-between border-b border-base-300 px-6 py-5">
        <h2 class="text-xl font-semibold">Planejado 2025</h2>
        <span :if={@planned_run} class="badge">{plan_status(@planned_run.status)}</span>
      </div>
      <p class="border-b border-base-300 px-6 py-3 text-sm opacity-70">
        O plano decide cada dia de 2025. Cada refinaria fica entre o piso
        de 94% e o teto de 100% de FUT. Se rendeu menos do que o plano, o
        piso dela sobe no dia seguinte. O rendimento diário é sorteado entre
        os meses válidos de cada refinaria em 2025, e um sorteio 0 vira a
        média nacional. O ano compara a gasolina refinada, menos as perdas
        no transporte, com a demanda do ano.
      </p>
      <p :if={is_nil(@planned_run)} class="px-6 py-8 text-sm opacity-60">Ainda não executado.</p>
      <div
        :if={@planned_run && @planned_run.status == :failed}
        class="alert alert-warning m-6 text-sm"
      >
        A simulação planejada falhou: {inspect(@planned_run.result)}
      </div>
      <div :if={@annual}>
        <div class="grid gap-x-10 gap-y-4 border-b border-base-300 px-6 py-6 sm:grid-cols-2">
          <.metric
            label="Produção fornecida"
            value={annual_volume(@annual.production_m3)}
            unit="Mm³"
          />
          <.metric
            label="Demanda-alvo"
            value={annual_volume(@annual.demand_m3)}
            unit="Mm³"
          />
          <.metric
            label="Saldo assinado"
            value={signed(@annual.balance_m3, &annual_volume/1)}
            unit={"Mm³ · #{@balance_label}"}
            value_class={@balance_class}
          />
          <.metric
            label="FUT Total"
            value={"#{fut_pct(@annual.total_fut_pct)}%"}
            unit="razão de somas"
          />
        </div>
        <div class="grid gap-x-10 gap-y-4 border-b border-base-300 px-6 py-6 sm:grid-cols-2">
          <h3 class="col-span-full text-sm font-semibold uppercase tracking-wide opacity-60">
            Detalhes do planejamento
          </h3>
          <.metric
            label="Demanda atendida"
            value={annual_volume(@annual.served_demand_m3)}
            unit="Mm³ no ano"
          />
          <.metric label="Déficit" value={annual_volume(@annual.deficit_m3)} unit="Mm³ não cobertos no ano" />
          <.metric
            label="Chegadas"
            value={annual_volume(@annual.landed_m3)}
            unit="Mm³"
          />
          <.metric
            label="Excedente"
            value={annual_volume(@annual.excess_m3)}
            unit="Mm³ acima da demanda"
          />
          <.metric
            label="Estoque nas plantas"
            value={annual_volume(@annual.plant_stock_m3)}
            unit="Mm³ no fim do ano"
          />
          <.metric
            label="Perdas no transporte"
            value={annual_volume(@annual.lost_m3)}
            unit="Mm³"
          />
          <.metric
            label="Cobertura anual"
            value={"#{pct(@annual.coverage)}%"}
            unit="demanda atendida"
          />
        </div>
        <div class="space-y-3 border-b border-base-300 px-6 py-5">
          <h3 class="text-sm font-semibold uppercase tracking-wide opacity-60">
            Demanda por região
          </h3>
          <div class="overflow-x-auto">
            <table class="w-full min-w-[44rem] text-sm">
              <thead>
                <tr class="border-b border-base-300 text-left text-xs uppercase tracking-wide opacity-60">
                  <th class="py-3 pr-4 font-medium">Região</th>
                  <th class="px-3 py-3 text-right font-medium">Demanda</th>
                  <th class="px-3 py-3 text-right font-medium">Produção</th>
                  <th class="px-3 py-3 text-right font-medium">Atendida</th>
                  <th class="px-3 py-3 text-right font-medium">Estoque</th>
                  <th class="py-3 pl-3 text-right font-medium">Cobertura</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-base-200">
                <tr :for={region <- @annual.regions} class="hover:bg-base-200/50">
                  <td class="py-3 pr-4 font-medium">{region_name(region.id)}</td>
                  <td class="px-3 py-3 text-right font-mono tabular-nums">
                    {annual_volume(region.demand_m3)} Mm³
                  </td>
                  <td class="px-3 py-3 text-right font-mono tabular-nums">
                    {annual_volume(region.produced_m3)} Mm³
                  </td>
                  <td class="px-3 py-3 text-right font-mono tabular-nums">
                    {annual_volume(region.served_m3)} Mm³
                  </td>
                  <td class="px-3 py-3 text-right font-mono tabular-nums">
                    {annual_volume(region.stock_m3)} Mm³
                  </td>
                  <td class="py-3 pl-3 text-right font-mono tabular-nums">
                    {pct(region.coverage)}%
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
        <div class="space-y-3 px-6 py-5">
          <h3 class="text-sm font-semibold uppercase tracking-wide opacity-60">
            Volumes mensais · 10³ m³
          </h3>
          <div class="overflow-x-auto">
            <table class="w-full min-w-[42rem] text-sm">
              <thead>
                <tr class="border-b border-base-300 text-left text-xs uppercase tracking-wide opacity-60">
                  <th class="py-3 pr-4 font-medium">Mês</th>
                  <th class="px-3 py-3 text-right font-medium">Produção fornecida</th>
                  <th class="px-3 py-3 text-right font-medium">Demanda-alvo</th>
                  <th class="px-3 py-3 text-right font-medium">Saldo assinado</th>
                  <th class="py-3 pl-3 text-right font-medium">FUT Total</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-base-200">
                <tr :for={month <- @months} class="hover:bg-base-200/50">
                  <td class="py-3 pr-4 font-medium whitespace-nowrap">{month.month}</td>
                  <td class="px-3 py-3 text-right font-mono tabular-nums">
                    {monthly_volume(month.production_m3)}
                  </td>
                  <td class="px-3 py-3 text-right font-mono tabular-nums">
                    {monthly_volume(month.demand_m3)}
                  </td>
                  <td class={[
                    "px-3 py-3 text-right font-mono tabular-nums",
                    elem(balance_info(month.balance_m3), 1)
                  ]}>
                    {signed(month.balance_m3, &monthly_volume/1)}
                  </td>
                  <td class="py-3 pl-3 text-right font-mono tabular-nums">
                    {fut_pct(month.total_fut_pct)}%
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :unit, :string, required: true
  attr :value_class, :string, default: nil

  defp metric(assigns) do
    ~H"""
    <div class="min-w-0">
      <div class="text-xs font-medium uppercase tracking-wide opacity-60">{@label}</div>
      <div class={["mt-1 font-mono text-xl font-semibold tabular-nums", @value_class]}>
        {@value}
      </div>
      <div class="mt-0.5 text-xs opacity-60">{@unit}</div>
    </div>
    """
  end
end
