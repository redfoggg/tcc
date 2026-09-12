defmodule GasolineSimulator.Scenarios.Orchestrator do
  use GenServer

  alias GasolineSimulator.Models.Plan
  alias GasolineSimulator.Refineries.Supervisor, as: PlantSupervisor
  alias GasolineSimulator.Scenarios.Runner

  @pubsub GasolineSimulator.PubSub
  @topic "plans"
  @default_timeout_ms 5_000

  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
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
    {:ok,
     %{
       plans: %{},
       refs: %{},
       plant_progress: %{},
       task_supervisor:
         Keyword.get(opts, :task_supervisor, GasolineSimulator.Scenarios.TaskSupervisor),
       timeout: Keyword.get(opts, :timeout, @default_timeout_ms)
     }}
  end

  @impl true
  def handle_call({:run_plan, params}, _from, state) do
    {min_year_ms, params} = Map.pop(params, :min_year_ms)
    id = generate_id()
    plan = %Plan{id: id, params: params, status: :running, started_at: DateTime.utc_now()}
    pid = self()

    runner_opts = [
      task_supervisor: state.task_supervisor,
      timeout: state.timeout,
      on_day: &GenServer.cast(pid, {:day_progress, &1})
    ]

    runner_opts =
      if is_integer(min_year_ms),
        do: Keyword.put(runner_opts, :min_year_ms, min_year_ms),
        else: runner_opts

    %{ref: ref} =
      Task.Supervisor.async_nolink(state.task_supervisor, Runner, :run, [params, runner_opts])

    {:reply, {:ok, plan},
     state
     |> put_in([:plans, id], plan)
     |> put_in([:refs, ref], id)
     |> publish_progress(%{})}
  end

  def handle_call({:disconnect_plant, id}, _from, state) do
    {:reply, PlantSupervisor.disconnect(id), zero_operating(state, id)}
  end

  def handle_call({:reconnect_plant, id}, _from, state) do
    case PlantSupervisor.reconnect(id) do
      {:ok, _pid} -> {:reply, :ok, zero_operating(state, id)}
      {:error, {:already_started, _pid}} -> {:reply, :ok, zero_operating(state, id)}
      {:error, :running} -> {:reply, :ok, state}
      other -> {:reply, other, state}
    end
  end

  def handle_call(:plant_statuses, _from, state) do
    {:reply, plant_cards(state.plant_progress), state}
  end

  @impl true
  def handle_cast({:day_progress, day}, state) do
    {:noreply, publish_progress(state, accumulate_progress(state.plant_progress, day))}
  end

  @impl true
  def handle_info({ref, result}, state) when is_reference(ref) do
    {:noreply, finish_task(state, ref, plan_outcome(result))}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    {:noreply, finish_task(state, ref, {:failed, reason})}
  end

  defp finish_task(state, ref, {status, result}) do
    case Map.pop(state.refs, ref) do
      {nil, _refs} ->
        state

      {id, refs} ->
        Process.demonitor(ref, [:flush])
        {plan, state} = update_plan(%{state | refs: refs}, id, status: status, result: result)
        broadcast({:plan_updated, plan})
        state
    end
  end

  defp plan_outcome({:ok, result}), do: {:completed, result}
  defp plan_outcome({:error, reason}), do: {:failed, reason}

  defp update_plan(state, id, changes) do
    plan =
      state.plans
      |> Map.fetch!(id)
      |> struct!(changes)
      |> Map.put(:completed_at, DateTime.utc_now())

    {plan, put_in(state, [:plans, id], plan)}
  end

  defp zero_operating(state, id) do
    publish_progress(state, put_fut(state.plant_progress, id, 0.0))
  end

  defp publish_progress(state, progress) do
    broadcast({:plants_updated, plant_cards(progress)})
    %{state | plant_progress: progress}
  end

  defp accumulate_progress(progress, day) do
    zeroed = Map.new(progress, fn {id, stats} -> {id, %{stats | fut_pct: 0.0}} end)

    Enum.reduce(day.refineries, zeroed, fn refinery, acc ->
      prev = Map.get(acc, refinery.id, %{fut_pct: 0.0, produced_m3: 0.0})

      Map.put(acc, refinery.id, %{
        fut_pct: refinery.fut_pct,
        produced_m3: prev.produced_m3 + refinery.allocated_m3
      })
    end)
  end

  defp put_fut(progress, id, fut_pct) do
    case progress do
      %{^id => stats} -> Map.put(progress, id, %{stats | fut_pct: fut_pct})
      _ -> progress
    end
  end

  defp plant_cards(progress) do
    Enum.map(PlantSupervisor.statuses(), fn plant ->
      stats = Map.get(progress, plant.id)

      plant
      |> Map.put(:fut_pct, if(plant.up, do: stats && stats.fut_pct, else: 0.0))
      |> Map.put(:produced_m3, stats && stats.produced_m3)
    end)
  end

  defp broadcast(message) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, message)
  end

  defp generate_id do
    16 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end
end
