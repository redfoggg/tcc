defmodule GasolineSimulator.Refineries.Fleet do
  alias GasolineSimulator.Refineries.DeliverySupervisor
  alias GasolineSimulator.Refineries.Plant

  def start(run, ids, observed \\ false, seed \\ nil, seed_path \\ nil) do
    {:ok, supervisor} = DynamicSupervisor.start_link(strategy: :one_for_one)
    {:ok, deliveries} = DynamicSupervisor.start_child(supervisor, DeliverySupervisor)

    fleet = %{
      run: run,
      supervisor: supervisor,
      deliveries: deliveries,
      observed: observed,
      seed: seed,
      seed_path: seed_path
    }

    Enum.each(ids, &restore(fleet, &1))
    fleet
  end

  def restore(fleet, id) do
    attrs = %{
      id: id,
      run: fleet.run,
      deliveries: fleet.deliveries,
      observed: fleet.observed,
      seed: fleet.seed,
      seed_path: fleet.seed_path
    }

    alive(fleet, fn -> DynamicSupervisor.start_child(fleet.supervisor, {Plant, attrs}) end)
  end

  def drop(fleet, id) do
    case Plant.pid(id, fleet.run) do
      nil -> {:error, :not_found}
      pid -> alive(fleet, fn -> DynamicSupervisor.terminate_child(fleet.supervisor, pid) end)
    end
  end

  def stop(fleet) do
    alive(fleet, fn -> DynamicSupervisor.stop(fleet.supervisor) end)
  end

  defp alive(_fleet, action) do
    try do
      action.()
    catch
      :exit, _reason -> {:error, :stopped}
    end
  end
end
