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
  defp fmt(nil, _divisor, _places), do: "n/a"

  defp fmt(value, divisor, places) do
    :erlang.float_to_binary(value / divisor * 1.0, decimals: places)
  end

  defp annual_volume(value), do: fmt(value, 1_000_000, 2)
  defp monthly_volume(value), do: fmt(value, 1_000, 1)

  defp pct(nil), do: "n/a"
  defp pct(value), do: fmt(value * 100.0)
  defp fut_pct(nil), do: "n/a"
  defp fut_pct(value), do: fmt(value)

  defp signed(value, formatter) when value > 0, do: "+#{formatter.(value)}"
  defp signed(value, formatter), do: formatter.(value)

  defp annual_of(%{result: %{annual: annual}}), do: annual
  defp annual_of(_other), do: nil

  defp months_of(%{result: %{months: months}}), do: months
  defp months_of(_other), do: []

  defp january_refineries(months) do
    months
    |> Enum.find(&(&1.month == "2025-01"))
    |> case do
      %{refineries: refineries} -> Enum.sort_by(refineries, & &1.id)
      _other -> []
    end
  end

  defp balance_info(value) when value > 0, do: {"surplus", "text-success"}
  defp balance_info(value) when value < 0, do: {"shortfall", "text-error"}
  defp balance_info(_value), do: {"balanced", "text-base-content"}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} wide>
      <div class="w-full space-y-10">
        <div class="max-w-4xl space-y-2">
          <h1 class="text-3xl font-bold tracking-tight">Gasoline A operations dashboard</h1>
          <p class="text-base leading-6 opacity-70">
            Historical 2025 displays the precomputed curated record. Planned 2025 samples a
            new gasoline A yield in 20% to 25% for every refinery-month, then runs one
            January-December inventory and deficit simulation.
          </p>
        </div>

        <div class="grid items-start gap-8 2xl:grid-cols-2">
          <.historical_panel historical={@historical} />
          <.planned_panel planned_run={@planned_run} />
        </div>

        <form phx-submit="run_plan" id="dashboard-planning-form" class="rounded border p-4 space-y-4">
          <h2 class="font-semibold">Planned 2025 controls</h2>

          <div class="grid gap-4 sm:grid-cols-2">
            <div>
              <label for="dashboard-initial-inventory" class="text-sm font-medium">
                Initial inventory on 2025-01-01 (m³, optional)
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
                Demand adjustment (%, optional)
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
                <th>Refinery</th>
                <th>Operating floor override (m³)</th>
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

          <.button id="dashboard-run-plan">Run Planned 2025</.button>
        </form>

        <.link
          :if={match?(%{status: :completed}, @planned_run)}
          id="dashboard-export-plan"
          href={~p"/api/plans/#{@planned_run.id}"}
          target="_blank"
          class="link link-primary text-sm"
        >
          Export Historical 2025 and Planned 2025 JSON
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
        <h2 class="text-xl font-semibold">Historical 2025</h2>
        <p class="text-sm leading-5 opacity-70">
          Static curated artifact. FUT Total uses observed petroleum processing and raw capacity.
        </p>
      </div>
      <div class="grid gap-x-10 gap-y-4 border-b border-base-300 px-6 py-6 sm:grid-cols-2">
        <.metric
          label="Supplied production"
          value={annual_volume(@historical.annual.production_supplied_m3)}
          unit="Mm³"
        />
        <.metric
          label="Demand target"
          value={annual_volume(@historical.annual.demand_target_m3)}
          unit="Mm³"
        />
        <.metric
          label="Signed balance"
          value={signed(@historical.annual.balance_m3, &annual_volume/1)}
          unit={"Mm³ · #{@balance_label}"}
          value_class={@balance_class}
        />
        <.metric
          label="FUT Total"
          value={"#{fut_pct(@historical.annual.total_fut_pct)}%"}
          unit="ratio-of-sums"
        />
      </div>
      <div class="space-y-3 px-6 py-5">
        <h3 class="text-sm font-semibold uppercase tracking-wide opacity-60">
          Monthly volumes · 10³ m³
        </h3>
        <div class="overflow-x-auto">
          <table class="w-full min-w-[42rem] text-sm">
            <thead>
              <tr class="border-b border-base-300 text-left text-xs uppercase tracking-wide opacity-60">
                <th class="py-3 pr-4 font-medium">Month</th>
                <th class="px-3 py-3 text-right font-medium">Supplied production</th>
                <th class="px-3 py-3 text-right font-medium">Demand target</th>
                <th class="px-3 py-3 text-right font-medium">Signed balance</th>
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
        <h2 class="text-xl font-semibold">Planned 2025</h2>
        <span :if={@planned_run} class="badge">{@planned_run.status}</span>
      </div>
      <p class="border-b border-base-300 px-6 py-3 text-sm opacity-70">
        Each run independently samples gasoline A yields from Uniform(0.20, 0.25).
      </p>
      <p :if={is_nil(@planned_run)} class="px-6 py-8 text-sm opacity-60">Not run yet.</p>
      <div
        :if={@planned_run && @planned_run.status == :failed}
        class="alert alert-warning m-6 text-sm"
      >
        Planning simulation failed: {inspect(@planned_run.result)}
      </div>
      <div :if={@annual}>
        <div class="grid gap-x-10 gap-y-4 border-b border-base-300 px-6 py-6 sm:grid-cols-2">
          <.metric
            label="Supplied production"
            value={annual_volume(@annual.production_m3)}
            unit="Mm³"
          />
          <.metric
            label="Demand target"
            value={annual_volume(@annual.demand_m3)}
            unit="Mm³"
          />
          <.metric
            label="Signed balance"
            value={signed(@annual.balance_m3, &annual_volume/1)}
            unit={"Mm³ · #{@balance_label}"}
            value_class={@balance_class}
          />
          <.metric
            label="FUT Total"
            value={"#{fut_pct(@annual.total_fut_pct)}%"}
            unit="ratio-of-sums"
          />
        </div>
        <div class="grid gap-x-10 gap-y-4 border-b border-base-300 px-6 py-6 sm:grid-cols-2">
          <h3 class="col-span-full text-sm font-semibold uppercase tracking-wide opacity-60">
            Planning details
          </h3>
          <.metric label="Served demand" value={annual_volume(@annual.served_demand_m3)} unit="Mm³" />
          <.metric label="Deficit" value={annual_volume(@annual.deficit_m3)} unit="Mm³" />
          <.metric
            label="Starting inventory"
            value={annual_volume(@annual.starting_inventory_m3)}
            unit="Mm³"
          />
          <.metric
            label="Ending inventory"
            value={annual_volume(@annual.ending_inventory_m3)}
            unit="Mm³"
          />
          <.metric label="Annual coverage" value={"#{pct(@annual.coverage)}%"} unit="served demand" />
        </div>
        <div class="space-y-3 px-6 py-5">
          <h3 class="text-sm font-semibold uppercase tracking-wide opacity-60">
            Monthly volumes · 10³ m³
          </h3>
          <div class="overflow-x-auto">
            <table class="w-full min-w-[42rem] text-sm">
              <thead>
                <tr class="border-b border-base-300 text-left text-xs uppercase tracking-wide opacity-60">
                  <th class="py-3 pr-4 font-medium">Month</th>
                  <th class="px-3 py-3 text-right font-medium">Supplied production</th>
                  <th class="px-3 py-3 text-right font-medium">Demand target</th>
                  <th class="px-3 py-3 text-right font-medium">Signed balance</th>
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
        <div :if={january_refineries(@months) != []} class="space-y-3 px-6 py-5">
          <h3 class="text-sm font-semibold uppercase tracking-wide opacity-60">
            January sampled yields
          </h3>
          <div class="overflow-x-auto">
            <table class="w-full min-w-[32rem] text-sm" id="dashboard-january-yields">
              <thead>
                <tr class="border-b border-base-300 text-left text-xs uppercase tracking-wide opacity-60">
                  <th class="py-3 pr-4 font-medium">Refinery</th>
                  <th class="px-3 py-3 text-right font-medium">Simulated yield</th>
                  <th class="py-3 pl-3 text-right font-medium">Allocation · 10³ m³</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-base-200">
                <tr :for={refinery <- january_refineries(@months)} class="hover:bg-base-200/50">
                  <td class="py-3 pr-4 font-medium whitespace-nowrap">
                    {refinery.name} ({refinery.id})
                  </td>
                  <td class="px-3 py-3 text-right font-mono tabular-nums">
                    {fmt(refinery.simulated_yield * 100.0)}%
                  </td>
                  <td class="py-3 pl-3 text-right font-mono tabular-nums">
                    {monthly_volume(refinery.allocated_m3)}
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
