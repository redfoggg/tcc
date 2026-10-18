defmodule GasolineSimulator.Solver do
  alias GasolineSimulator.Solver.Native

  @default_timeout_ms 5_000
  @default_task_supervisor GasolineSimulator.Scenarios.TaskSupervisor

  @type facility_input :: %{
          id: String.t(),
          region: String.t(),
          capacity: number(),
          floor: number()
        }

  @type region_input :: %{
          id: String.t(),
          demand: number(),
          landed: number()
        }

  @type solver_input :: %{
          demand: number(),
          landed: number(),
          regions: [region_input()],
          facilities: [facility_input()]
        }

  @type facility_result :: %{id: String.t(), allocated: float()}

  @type error_kind :: :solver_failure | :solver_panic | :timeout

  @spec solve(solver_input(), keyword()) ::
          {:ok, [facility_result()]} | {:error, {error_kind(), String.t()}}
  def solve(input, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout_ms)
    task_supervisor = Keyword.get(opts, :task_supervisor, @default_task_supervisor)

    run_with_timeout(input, task_supervisor, timeout)
  end

  defp run_with_timeout(native_input, task_supervisor, timeout) do
    task =
      Task.Supervisor.async_nolink(task_supervisor, fn -> call_native(native_input, timeout) end)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} -> result
      nil -> {:error, {:timeout, "solver did not complete within #{timeout}ms"}}
      {:exit, reason} -> {:error, {:solver_panic, inspect(reason)}}
    end
  end

  defp call_native(input, timeout_ms) do
    Native.solve_nif(input, timeout_ms / 1000)
  rescue
    error -> {:error, {:solver_panic, Exception.message(error)}}
  end
end
