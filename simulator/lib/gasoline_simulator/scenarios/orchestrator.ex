defmodule GasolineSimulator.Scenarios.Orchestrator do
  use GenServer

  alias GasolineSimulator.Models.Plan
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

  def get_plan(id, server \\ __MODULE__) do
    GenServer.call(server, {:get_plan, id})
  end

  def subscribe do
    Phoenix.PubSub.subscribe(@pubsub, @topic)
  end

  @impl true
  def init(opts) do
    task_supervisor =
      Keyword.get(opts, :task_supervisor, GasolineSimulator.Scenarios.TaskSupervisor)

    timeout = Keyword.get(opts, :timeout, @default_timeout_ms)

    {:ok, %{plans: %{}, refs: %{}, task_supervisor: task_supervisor, timeout: timeout}}
  end

  @impl true
  def handle_call({:run_plan, params}, _from, state) do
    id = generate_id()
    plan = %Plan{id: id, params: params, status: :running, started_at: DateTime.utc_now()}

    runner_opts = [task_supervisor: state.task_supervisor, timeout: state.timeout]

    %Task{ref: ref} =
      Task.Supervisor.async_nolink(state.task_supervisor, Runner, :run, [params, runner_opts])

    state =
      state
      |> put_in([:plans, id], plan)
      |> put_in([:refs, ref], id)

    {:reply, {:ok, plan}, state}
  end

  @impl true
  def handle_call({:get_plan, id}, _from, state) do
    {:reply, Map.fetch(state.plans, id), state}
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
  def handle_info({:DOWN, ref, :process, _pid, reason}, %{refs: refs} = state) do
    case Map.pop(refs, ref) do
      {nil, _refs} ->
        {:noreply, state}

      {id, remaining_refs} ->
        {plan, state} = fail_plan(%{state | refs: remaining_refs}, id, reason)
        broadcast(plan)
        {:noreply, state}
    end
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

  defp generate_id do
    16 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end
end
