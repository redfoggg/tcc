defmodule GasolineSimulator.Scenarios.Study do
  use GenServer

  alias GasolineSimulator.Scenarios.Methodology

  @pubsub GasolineSimulator.PubSub
  @topic "studies"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: Keyword.get(opts, :name, __MODULE__))
  end

  def start(server \\ __MODULE__) do
    GenServer.call(server, :start)
  end

  def status(server \\ __MODULE__) do
    GenServer.call(server, :status)
  end

  def subscribe do
    Phoenix.PubSub.subscribe(@pubsub, @topic)
  end

  @impl true
  def init(:ok) do
    {:ok,
     %{
       status: :idle,
       output_dir: nil,
       scenario_id: nil,
       scenario_index: 0,
       scenario_count: length(Methodology.scenarios()),
       run: 0,
       runs: Methodology.runs(),
       completed: 0,
       error: nil,
       ref: nil
     }}
  end

  @impl true
  def handle_call(:start, _from, %{status: :running} = state) do
    {:reply, {:error, :already_running}, state}
  end

  def handle_call(:start, _from, state) do
    output_dir = Path.join(studies_dir(), timestamp())
    parent = self()

    %{ref: ref} =
      Task.Supervisor.async_nolink(GasolineSimulator.Scenarios.TaskSupervisor, fn ->
        Methodology.run(output_dir, fn progress -> send(parent, {:study_progress, progress}) end)
      end)

    state = %{
      state
      | status: :running,
        output_dir: output_dir,
        error: nil,
        ref: ref,
        scenario_id: nil,
        scenario_index: 0,
        scenario_count: length(Methodology.scenarios()),
        run: 0,
        runs: Methodology.runs(),
        completed: 0
    }

    broadcast(state)
    {:reply, {:ok, view(state)}, state}
  end

  def handle_call(:status, _from, state) do
    {:reply, view(state), state}
  end

  @impl true
  def handle_info({:study_progress, progress}, state) do
    {:noreply, state |> Map.merge(progress) |> broadcast()}
  end

  def handle_info({ref, :ok}, %{ref: ref} = state) do
    Process.demonitor(ref, [:flush])
    {:noreply, finish(state, :completed, nil)}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{ref: ref} = state) do
    {:noreply, finish(state, :failed, inspect(reason))}
  end

  defp finish(state, status, error) do
    state
    |> Map.merge(%{status: status, error: error, ref: nil})
    |> broadcast()
  end

  defp broadcast(state) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, {:study_updated, view(state)})
    state
  end

  defp view(state) do
    Map.take(state, [
      :status,
      :output_dir,
      :scenario_id,
      :scenario_index,
      :scenario_count,
      :run,
      :runs,
      :completed,
      :error
    ])
  end

  defp studies_dir do
    Path.join(Application.fetch_env!(:gasoline_simulator, :data_dir), "studies")
  end

  defp timestamp do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601(:basic)
  end
end
