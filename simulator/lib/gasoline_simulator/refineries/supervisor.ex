defmodule GasolineSimulator.Refineries.Supervisor do
  use DynamicSupervisor

  alias GasolineSimulator.Data.Catalog
  alias GasolineSimulator.Refineries.Plant

  def start_link(opts) do
    {:ok, pid} = DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
    Enum.each(Catalog.all(), &start_plant/1)
    {:ok, pid}
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  defp start_plant(attrs) do
    DynamicSupervisor.start_child(__MODULE__, {Plant, attrs})
  end

  def alive_ids do
    Catalog.ids()
    |> Enum.filter(&Plant.pid/1)
  end

  def statuses do
    alive = MapSet.new(alive_ids())

    Enum.map(Catalog.all(), fn plant ->
      Map.put(plant, :up, MapSet.member?(alive, plant.id))
    end)
  end

  def disconnect(id) do
    case Plant.pid(id) do
      nil -> {:error, :not_found}
      pid -> DynamicSupervisor.terminate_child(__MODULE__, pid)
    end
  end

  def reconnect(id) do
    case Plant.pid(id) do
      pid when is_pid(pid) -> {:error, :running}
      nil -> start_plant(Catalog.find(id))
    end
  end
end
