defmodule GasolineSimulatorWeb.PlanningController do
  use GasolineSimulatorWeb, :controller

  alias GasolineSimulator.Historical
  alias GasolineSimulator.Scenarios.Orchestrator
  alias GasolineSimulator.Scenarios.PlanningExport

  def show(conn, %{"planned_id" => planned_id}) do
    case Orchestrator.get_plan(planned_id) do
      {:ok, planned} ->
        json(conn, PlanningExport.build(Historical.load(), planned))

      :error ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "planned run not found", id: planned_id})
    end
  end
end
