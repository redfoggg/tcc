defmodule GasolineSimulator.Refineries.DeliverySupervisor do
  alias GasolineSimulator.Refineries.Delivery

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {DynamicSupervisor, :start_link, [Keyword.put(opts, :strategy, :one_for_one)]},
      type: :supervisor,
      restart: :temporary
    }
  end

  def start_delivery(supervisor, attrs) do
    id = "DLV-#{System.unique_integer([:positive])}"
    attrs = Map.put(attrs, :id, id)

    case DynamicSupervisor.start_child(supervisor, {Delivery, attrs}) do
      {:ok, pid} -> {:ok, pid, id}
      other -> other
    end
  end

  def fail(supervisor, pid), do: DynamicSupervisor.terminate_child(supervisor, pid)

  def statuses, do: Delivery.statuses()
end
