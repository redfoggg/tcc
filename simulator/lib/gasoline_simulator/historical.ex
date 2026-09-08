defmodule GasolineSimulator.Historical do
  @artifact "historical_2025_summary.json"

  @spec load(keyword()) :: map()
  def load(opts \\ []) do
    data_dir =
      Keyword.get(opts, :data_dir, Application.fetch_env!(:gasoline_simulator, :data_dir))

    data_dir
    |> Path.join("curated")
    |> Path.join(@artifact)
    |> File.read!()
    |> Jason.decode!(keys: :atoms)
  end
end
