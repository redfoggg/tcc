defmodule GasolineSimulatorWeb.Router do
  use GasolineSimulatorWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GasolineSimulatorWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", GasolineSimulatorWeb do
    pipe_through :browser

    live "/", DashboardLive
    live "/dashboard", DashboardLive
  end

  scope "/api", GasolineSimulatorWeb do
    pipe_through :api

    get "/plans/:planned_id", PlanningController, :show
  end
end
