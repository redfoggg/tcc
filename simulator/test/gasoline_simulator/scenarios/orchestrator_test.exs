defmodule GasolineSimulator.Scenarios.OrchestratorTest do
  use ExUnit.Case, async: false

  alias GasolineSimulator.Scenarios.Orchestrator

  @moduletag :annual_smoke
  @moduletag timeout: 120_000

  test "plant statuses accumulate production and last-day FUT during a run" do
    Orchestrator.subscribe()

    assert {:ok, plan} = Orchestrator.run_plan(%{min_year_ms: 0})
    assert_receive {:plan_updated, %{id: id, status: :completed}}, 120_000
    assert id == plan.id

    repar = Enum.find(Orchestrator.plant_statuses(), &(&1.id == "REPAR"))
    assert repar.up
    assert repar.produced_m3 > 0.0
    assert is_float(repar.fut_pct)
  end

  test "a disconnected plant shows zero FUT and keeps produced volume" do
    Orchestrator.subscribe()

    assert {:ok, _plan} = Orchestrator.run_plan(%{min_year_ms: 0})
    assert_receive {:plan_updated, %{status: :completed}}, 120_000

    produced =
      Orchestrator.plant_statuses()
      |> Enum.find(&(&1.id == "REPAR"))
      |> Map.fetch!(:produced_m3)

    flush_pubsub()
    assert :ok = Orchestrator.disconnect_plant("REPAR")
    assert_receive {:plants_updated, plants}, 1_000

    repar = Enum.find(plants, &(&1.id == "REPAR"))
    refute repar.up
    assert_in_delta repar.fut_pct, 0.0, 1.0e-9
    assert_in_delta repar.produced_m3, produced, 1.0e-6
  after
    Orchestrator.reconnect_plant("REPAR")
  end

  defp flush_pubsub do
    receive do
      {:plants_updated, _} -> flush_pubsub()
      {:plan_updated, _} -> flush_pubsub()
    after
      0 -> :ok
    end
  end
end
