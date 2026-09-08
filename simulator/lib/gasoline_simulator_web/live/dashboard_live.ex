defmodule GasolineSimulatorWeb.DashboardLive do
  use GasolineSimulatorWeb, :live_view

  alias GasolineSimulator.Data.Repository
  alias GasolineSimulator.Data.Historical
  alias GasolineSimulator.Scenarios.Orchestrator

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Orchestrator.subscribe()

    socket =
      socket
      |> assign(
        page_title: "Painel de alocação de gasolina A",
        historical: Historical.load(),
        initial_inventory_m3: nil,
        demand_adjustment_pct: nil,
        floor_overrides: %{},
        planned_run: nil
      )
      |> load_setup_refineries()

    {:ok, socket}
  end

  @impl true
  def handle_event("run_plan", params, socket) do
    initial_inventory_m3 = params |> Map.get("initial_inventory_m3") |> parse_float_input()
    demand_adjustment_pct = params |> Map.get("demand_adjustment_pct") |> parse_float_input()
    floor_overrides = params |> Map.get("floor_overrides", %{}) |> parse_float_map()

    controls = %{
      initial_inventory_m3: initial_inventory_m3,
      demand_adjustment_pct: demand_adjustment_pct,
      floor_overrides: floor_overrides
    }

    {:ok, planned_run} = Orchestrator.run_plan(controls)

    {:noreply,
     assign(socket,
       planned_run: planned_run,
       initial_inventory_m3: initial_inventory_m3,
       demand_adjustment_pct: demand_adjustment_pct,
       floor_overrides: floor_overrides
     )}
  end

  @impl true
  def handle_info({:plan_updated, %{id: id} = planned_run}, socket) do
    case socket.assigns.planned_run do
      %{id: ^id} -> {:noreply, assign(socket, planned_run: planned_run)}
      _other -> {:noreply, socket}
    end
  end

  defp load_setup_refineries(socket) do
    refineries =
      Repository.load_year()
      |> Map.fetch!(:refineries_by_month)
      |> Map.fetch!(1)
      |> Enum.map(fn refinery ->
        %{id: refinery.id, name: refinery.name, uf: refinery.uf, floor_m3: refinery.floor_m3}
      end)
      |> Enum.sort_by(& &1.id)

    assign(socket, refineries: refineries)
  end

  defp parse_float_input(nil), do: nil
  defp parse_float_input(""), do: nil

  defp parse_float_input(value) do
    case Float.parse(value) do
      {number, _rest} -> number
      :error -> nil
    end
  end

  defp parse_float_map(params) do
    params
    |> Map.new(fn {id, value} -> {id, parse_float_input(value)} end)
    |> Map.reject(fn {_id, value} -> is_nil(value) end)
  end

  defp fmt(value, divisor \\ 1, places \\ 1)
  defp fmt(nil, _divisor, _places), do: "n/d"

  defp fmt(value, divisor, places) do
    :erlang.float_to_binary(value / divisor * 1.0, decimals: places)
  end

  defp annual_volume(value), do: fmt(value, 1_000_000, 2)
  defp monthly_volume(value), do: fmt(value, 1_000, 1)

  defp pct(nil), do: "n/d"
  defp pct(value), do: fmt(value * 100.0)
  defp fut_pct(nil), do: "n/d"
  defp fut_pct(value), do: fmt(value)

  defp signed(value, formatter) when value > 0, do: "+#{formatter.(value)}"
  defp signed(value, formatter), do: formatter.(value)

  defp annual_of(%{result: %{annual: annual}}), do: annual
  defp annual_of(_other), do: nil

  defp months_of(%{result: %{months: months}}), do: months
  defp months_of(_other), do: []

  defp balance_info(value) when value > 0, do: {"superávit", "text-success"}
  defp balance_info(value) when value < 0, do: {"déficit", "text-error"}
  defp balance_info(_value), do: {"equilibrado", "text-base-content"}

  defp plan_status(:pending), do: "pendente"
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
            O Histórico 2025 mostra o registro curado pré-computado. O Planejado 2025
            sorteia um rendimento de gasolina A entre 20% e 25% para cada refinaria-mês
            e executa uma simulação de estoque e déficit de janeiro a dezembro.
          </p>
        </div>

        <div class="grid items-start gap-8 2xl:grid-cols-2">
          <.historical_panel historical={@historical} />
          <.planned_panel planned_run={@planned_run} />
        </div>

        <form phx-submit="run_plan" id="dashboard-planning-form" class="rounded border p-4 space-y-4">
          <h2 class="font-semibold">Controles do Planejado 2025</h2>

          <div class="grid gap-4 sm:grid-cols-2">
            <div>
              <label for="dashboard-initial-inventory" class="text-sm font-medium">
                Estoque inicial em 2025-01-01 (m³, opcional)
              </label>
              <input
                type="number"
                step="any"
                name="initial_inventory_m3"
                id="dashboard-initial-inventory"
                value={@initial_inventory_m3}
                class="input input-bordered"
              />
            </div>

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

          <table class="w-full text-sm">
            <thead>
              <tr class="text-left opacity-70">
                <th>Refinaria</th>
                <th>Substituição do piso operacional (m³)</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={refinery <- @refineries} id={"dashboard-refinery-row-#{refinery.id}"}>
                <td>{refinery.name} ({refinery.id})</td>
                <td>
                  <input
                    type="number"
                    step="any"
                    name={"floor_overrides[#{refinery.id}]"}
                    id={"dashboard-floor-override-#{refinery.id}"}
                    value={Map.get(@floor_overrides, refinery.id)}
                    placeholder={Float.round(refinery.floor_m3, 1)}
                    class="input input-bordered input-sm"
                  />
                </td>
              </tr>
            </tbody>
          </table>

          <.button id="dashboard-run-plan">Executar Planejado 2025</.button>
        </form>

        <.link
          :if={match?(%{status: :completed}, @planned_run)}
          id="dashboard-export-plan"
          href={~p"/api/plans/#{@planned_run.id}"}
          target="_blank"
          class="link link-primary text-sm"
        >
          Exportar JSON do Histórico 2025 e do Planejado 2025
        </.link>
      </div>
    </Layouts.app>
    """
  end

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
          Artefato curado estático. O FUT Total usa o processamento de petróleo observado e a capacidade bruta.
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
        Cada execução sorteia rendimentos de gasolina A de forma independente em Uniform(0.20, 0.25).
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
            unit="Mm³"
          />
          <.metric label="Déficit" value={annual_volume(@annual.deficit_m3)} unit="Mm³" />
          <.metric
            label="Estoque inicial"
            value={annual_volume(@annual.starting_inventory_m3)}
            unit="Mm³"
          />
          <.metric
            label="Estoque final"
            value={annual_volume(@annual.ending_inventory_m3)}
            unit="Mm³"
          />
          <.metric
            label="Cobertura anual"
            value={"#{pct(@annual.coverage)}%"}
            unit="demanda atendida"
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
