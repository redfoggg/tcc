defmodule GasolineSimulator.Refineries.SupervisorTest do
  use ExUnit.Case, async: false

  alias GasolineSimulator.Data.Catalog
  alias GasolineSimulator.Refineries.Plant
  alias GasolineSimulator.Refineries.Supervisor
  alias GasolineSimulator.Scenarios.Runner

  setup do
    on_exit(fn ->
      Enum.each(Catalog.ids(), fn id ->
        if is_nil(Plant.pid(id)) do
          Supervisor.reconnect(id)
        end
      end)
    end)

    :ok
  end

  test "starts one process per catalog plant" do
    assert Supervisor.alive_ids() == Catalog.ids()
    assert Enum.all?(Supervisor.statuses(), & &1.up)
  end

  test "disconnect removes the plant until reconnect" do
    pid = Plant.pid("REPAR")
    ref = Process.monitor(pid)

    assert :ok = Supervisor.disconnect("REPAR")
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 1000
    refute "REPAR" in Supervisor.alive_ids()
    refute Enum.find(Supervisor.statuses(), &(&1.id == "REPAR")).up

    assert {:ok, _pid} = Supervisor.reconnect("REPAR")
    assert "REPAR" in Supervisor.alive_ids()
  end

  @tag :annual_smoke
  @tag timeout: 120_000
  test "a disconnected plant stays out of the planned year" do
    assert :ok = Supervisor.disconnect("REPAR")

    assert {:ok, %{days: days, annual: annual}} = Runner.run(%{}, min_year_ms: 0)

    assert Enum.all?(days, fn day ->
             ids = Enum.map(day.refineries, & &1.id)
             length(ids) == 11 and "REPAR" not in ids
           end)

    assert annual.demand_m3 > 0.0
  end
end
