defmodule GasolineSimulator.Scenarios.Plan do
  @enforce_keys [:id, :params]
  defstruct [:id, :params, :result, :started_at, :completed_at, status: :pending]

  @type status :: :pending | :running | :completed | :failed

  @type t :: %__MODULE__{
          id: String.t(),
          params: map(),
          status: status(),
          result: term(),
          started_at: DateTime.t() | nil,
          completed_at: DateTime.t() | nil
        }
end
