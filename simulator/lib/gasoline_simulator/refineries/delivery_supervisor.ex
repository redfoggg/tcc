defmodule GasolineSimulator.Refineries.DeliverySupervisor do
  use DynamicSupervisor

  alias GasolineSimulator.Refineries.Delivery

  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_delivery(attrs) do
    id = "DLV-#{System.unique_integer([:positive])}"
    attrs = Map.put(attrs, :id, id)

    case DynamicSupervisor.start_child(__MODULE__, {Delivery, attrs}) do
      {:ok, pid} -> {:ok, pid, id}
      {:error, {:already_started, pid}} -> {:ok, pid, id}
      other -> other
    end
  end

  def fail(id) do
    case Delivery.pid(id) do
      nil -> {:error, :absent}
      pid -> DynamicSupervisor.terminate_child(__MODULE__, pid)
    end
  end

  def stop_run(run_id) do
    Enum.each(Delivery.statuses(), fn delivery ->
      if delivery.run_id == run_id do
        pid = Delivery.pid(delivery.id)
        if pid, do: GenServer.stop(pid, :normal)
      end
    end)

    :ok
  end

  def statuses, do: Delivery.statuses()
end
