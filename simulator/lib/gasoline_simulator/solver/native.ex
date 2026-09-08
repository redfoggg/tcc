defmodule GasolineSimulator.Solver.Native do
  use Rustler,
    otp_app: :gasoline_simulator,
    crate: :gasoline_solver,
    path: "native/gasoline_solver"

  def solve_nif(_input, _time_limit_secs), do: :erlang.nif_error(:nif_not_loaded)
end
