defmodule GasolineSimulator.Scenarios.Orchestrator do
  use GenServer

  alias GasolineSimulator.Models.Plan
  alias GasolineSimulator.Refineries.Plant
  alias GasolineSimulator.Refineries.Supervisor, as: PlantSupervisor
  alias GasolineSimulator.Scenarios.Runner

  @pubsub GasolineSimulator.PubSub
  @topic "plans"
  @default_timeout_ms 5_000

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    gen_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, opts, gen_opts)
  end

  def run_plan(params, server \\ __MODULE__) do
    GenServer.call(server, {:run_plan, params})
  end

  def disconnect_plant(id, server \\ __MODULE__) do
    GenServer.call(server, {:disconnect_plant, id})
  end

  def reconnect_plant(id, server \\ __MODULE__) do
    GenServer.call(server, {:reconnect_plant, id})
  end

  def plant_statuses(server \\ __MODULE__) do
    GenServer.call(server, :plant_statuses)
  end

  def subscribe do
    Phoenix.PubSub.subscribe(@pubsub, @topic)
  end

  @impl true
  def init(opts) do
    task_supervisor =
      Keyword.get(opts, :task_supervisor, GasolineSimulator.Scenarios.TaskSupervisor)

    timeout = Keyword.get(opts, :timeout, @default_timeout_ms)

    {:ok,
     %{
       plans: %{},
       refs: %{},
       plant_progress: %{},
       plant_monitors: monitor_alive_plants(),
       task_supervisor: task_supervisor,
       timeout: timeout
     }}
  end

  @impl true
  def handle_call({:run_plan, params}, _from, state) do
    id = generate_id()
    {min_year_ms, params} = Map.pop(params, :min_year_ms)
    plan = %Plan{id: id, params: params, status: :running, started_at: DateTime.utc_now()}
    orchestrator = self()

    runner_opts =
      [
        task_supervisor: state.task_supervisor,
        timeout: state.timeout,
        on_day: fn day -> GenServer.cast(orchestrator, {:day_progress, day}) end
      ]
      |> then(fn opts ->
        if is_nil(min_year_ms), do: opts, else: Keyword.put(opts, :min_year_ms, min_year_ms)
      end)

    %Task{ref: ref} =
      Task.Supervisor.async_nolink(state.task_supervisor, Runner, :run, [params, runner_opts])

    broadcast_plants(%{})

    state =
      state
      |> put_in([:plans, id], plan)
      |> put_in([:refs, ref], id)
      |> Map.put(:plant_progress, %{})

    {:reply, {:ok, plan}, state}
  end

  def handle_call({:disconnect_plant, id}, _from, state) do
    result = PlantSupervisor.disconnect(id)
    progress = set_operating(state.plant_progress, id, 0.0)
    broadcast_plants(progress)
    {:reply, result, %{state | plant_progress: progress}}
  end

  def handle_call({:reconnect_plant, id}, _from, state) do
    case PlantSupervisor.reconnect(id) do
      {:ok, pid} ->
        {:reply, :ok, mark_reconnected(state, id, pid)}

      {:error, {:already_started, pid}} ->
        {:reply, :ok, mark_reconnected(state, id, pid)}

      {:error, :running} ->
        {:reply, :ok, state}

      other ->
        {:reply, other, state}
    end
  end

  def handle_call(:plant_statuses, _from, state) do
    {:reply, decorate_plants(state.plant_progress), state}
  end

  @impl true
  def handle_cast({:day_progress, day}, state) do
    progress = accumulate_progress(state.plant_progress, day)
    broadcast_plants(progress)
    {:noreply, %{state | plant_progress: progress}}
  end

  @impl true
  def handle_info({ref, result}, %{refs: refs} = state) when is_reference(ref) do
    case Map.pop(refs, ref) do
      {nil, _refs} ->
        {:noreply, state}

      {id, remaining_refs} ->
        Process.demonitor(ref, [:flush])
        {plan, state} = finish_plan(%{state | refs: remaining_refs}, id, result)
        broadcast(plan)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    cond do
      Map.has_key?(state.plant_monitors, ref) ->
        {id, plant_monitors} = Map.pop!(state.plant_monitors, ref)
        progress = set_operating(state.plant_progress, id, 0.0)
        broadcast_plants(progress)

        {:noreply, %{state | plant_monitors: plant_monitors, plant_progress: progress}}

      Map.has_key?(state.refs, ref) ->
        {id, remaining_refs} = Map.pop!(state.refs, ref)
        {plan, state} = fail_plan(%{state | refs: remaining_refs}, id, reason)
        broadcast(plan)
        {:noreply, state}

      true ->
        {:noreply, state}
    end
  end

  defp monitor_alive_plants do
    Map.new(PlantSupervisor.alive_ids(), fn id ->
      {Process.monitor(Plant.pid(id)), id}
    end)
  end

  defp finish_plan(state, id, {:ok, result}) do
    update_plan(state, id, status: :completed, result: result)
  end

  defp finish_plan(state, id, {:error, reason}) do
    update_plan(state, id, status: :failed, result: reason)
  end

  defp fail_plan(state, id, reason) do
    update_plan(state, id, status: :failed, result: reason)
  end

  defp update_plan(state, id, changes) do
    plan =
      state.plans
      |> Map.fetch!(id)
      |> struct!(changes)
      |> Map.put(:completed_at, DateTime.utc_now())

    {plan, put_in(state, [:plans, id], plan)}
  end

  defp broadcast(plan) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, {:plan_updated, plan})
  end

  defp mark_reconnected(state, id, pid) do
    ref = Process.monitor(pid)
    progress = set_operating(state.plant_progress, id, 0.0)
    broadcast_plants(progress)

    state
    |> put_in([:plant_monitors, ref], id)
    |> Map.put(:plant_progress, progress)
  end

  defp accumulate_progress(progress, day) do
    present = MapSet.new(Enum.map(day.refineries, & &1.id))

    progress =
      Map.new(progress, fn {id, stats} ->
        if MapSet.member?(present, id) do
          {id, stats}
        else
          {id, %{stats | fut_pct: 0.0}}
        end
      end)

    Enum.reduce(day.refineries, progress, fn refinery, acc ->
      prev = Map.get(acc, refinery.id, %{fut_pct: 0.0, produced_m3: 0.0})

      Map.put(acc, refinery.id, %{
        fut_pct: refinery.fut_pct,
        produced_m3: prev.produced_m3 + refinery.allocated_m3
      })
    end)
  end

  defp set_operating(progress, id, fut_pct) do
    case Map.get(progress, id) do
      nil -> progress
      stats -> Map.put(progress, id, %{stats | fut_pct: fut_pct})
    end
  end

  defp decorate_plants(progress) do
    Enum.map(PlantSupervisor.statuses(), fn plant ->
      stats = Map.get(progress, plant.id)

      plant
      |> Map.put(:fut_pct, operating_fut(plant.up, stats))
      |> Map.put(:produced_m3, stats && stats.produced_m3)
    end)
  end

  defp operating_fut(false, _stats), do: 0.0
  defp operating_fut(true, nil), do: nil
  defp operating_fut(true, stats), do: stats.fut_pct

  defp broadcast_plants(progress) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, {:plants_updated, decorate_plants(progress)})
  end

  defp generate_id do
    16 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end
end
