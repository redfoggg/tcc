defmodule GasolineSimulator.Scenarios.Seed do
  @algorithm :exsss
  @range 4_294_967_296
  @max_seed 999_999_999

  def new, do: :rand.uniform(@max_seed)

  def plant(nil, _path), do: :ok
  def plant(seed, path), do: :rand.seed(@algorithm, state({seed, path}))

  defp state(key), do: {hash(key, 1), hash(key, 2), hash(key, 3)}

  defp hash(key, part), do: :erlang.phash2({key, part}, @range)
end
