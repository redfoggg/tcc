defmodule GasolineSimulatorWeb.DashboardLiveTest do
  use GasolineSimulatorWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  test "the plant panel renders live FUT and produced volume", %{conn: conn} do
    {:ok, view, html} = live(conn, "/")

    assert html =~ "Operando"
    assert html =~ "Produzido"

    send(view.pid, {:plants_updated,
     [
       %{
         id: "REPAR",
         name: "Refinaria Presidente Getúlio Vargas",
         uf: "PR",
         up: true,
         fut_pct: 40.0,
         produced_m3: 1234.0
       }
     ]})

    rendered = render(view)
    assert rendered =~ "Operando 40.0%"
    assert rendered =~ "Produzido 1234 m³"
    assert rendered =~ "dashboard-plant-fut-REPAR"
  end
end
