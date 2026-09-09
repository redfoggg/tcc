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

  scope "/", GasolineSimulatorWeb do
    pipe_through :browser

    live "/", DashboardLive
  end
end
