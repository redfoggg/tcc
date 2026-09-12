defmodule GasolineSimulator.Refineries.Plant do
  use GenServer

  @registry GasolineSimulator.Refineries.Registry

  def child_spec(attrs) do
    %{
      id: attrs.id,
      start: {__MODULE__, :start_link, [attrs]},
      restart: :temporary
    }
  end

  def start_link(attrs) do
    GenServer.start_link(__MODULE__, attrs, name: via(attrs.id))
  end

  defp via(id), do: {:via, Registry, {@registry, id}}

  def pid(id) do
    case Registry.lookup(@registry, id) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  @impl true
  def init(attrs), do: {:ok, attrs}
end
