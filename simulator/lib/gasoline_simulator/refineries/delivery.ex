defmodule GasolineSimulator.Refineries.Delivery do
  use GenServer

  @registry GasolineSimulator.Refineries.DeliveryRegistry

  def child_spec(attrs) do
    %{
      id: attrs.id,
      start: {__MODULE__, :start_link, [attrs]},
      restart: :temporary
    }
  end

  def start_link(%{observed: true} = attrs) do
    GenServer.start_link(__MODULE__, attrs, name: via(attrs))
  end

  def start_link(attrs) do
    GenServer.start_link(__MODULE__, attrs)
  end

  def claim(pid, day) when is_pid(pid) do
    try do
      GenServer.call(pid, {:claim, day})
    catch
      :exit, _reason -> {:error, :absent}
    end
  end

  def statuses do
    Registry.select(@registry, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$3"}}]}])
    |> Enum.map(fn {id, summary} -> Map.put(summary, :id, id) end)
  end

  @impl true
  def init(attrs) do
    {:ok, Map.put(attrs, :volume_m3, attrs.volume_m3 * 1.0)}
  end

  @impl true
  def handle_call({:claim, day}, _from, state) do
    if not Date.after?(state.arrival, day) do
      {:stop, :normal, {:ok, state.volume_m3}, state}
    else
      {:reply, {:ok, 0.0}, state}
    end
  end

  defp via(attrs) do
    {:via, Registry, {@registry, attrs.id, Map.drop(attrs, [:id])}}
  end
end
