defmodule GasolineSimulator.Refineries.Logistics do
  alias GasolineSimulator.Refineries.DeliverySupervisor
  alias GasolineSimulator.Refineries.Plant

  def clear(ids, run_id) do
    DeliverySupervisor.stop_run(run_id)
    Enum.each(ids, &Plant.reset(&1, run_id))
    :ok
  end

  def landed(ids, day, run_id) do
    Enum.reduce(ids, {[], 0.0}, fn id, {present, volume} ->
      case Plant.arrivals(id, day, run_id) do
        {:ok, arrived} -> {[id | present], volume + arrived}
        {:error, :absent} -> {present, volume}
      end
    end)
    |> then(fn {present, volume} -> {Enum.reverse(present), volume} end)
  end

  @convoy_m3 30.0
  @convoy_min_m3 20.0

  def dispatch(result, day, present, run_id, failure_pct \\ %{}, closed_roads \\ MapSet.new()) do
    result.refineries
    |> Enum.filter(&(&1.id in present))
    |> reliefs()
    |> Enum.each(&place(&1, day, run_id, failure_pct, closed_roads))

    result
  end

  defp place({_origin, volume, _destinations}, _day, _run_id, _failure_pct, _closed_roads)
       when volume <= 0.0,
       do: :ok

  defp place({origin, volume, destinations}, day, run_id, failure_pct, closed_roads) do
    volume
    |> convoys()
    |> Enum.each(&ship_convoy(origin, &1, destinations, day, run_id, failure_pct, closed_roads))
  end

  defp ship_convoy(origin, volume, destinations, day, run_id, failure_pct, closed_roads) do
    case Plant.ship(origin, volume, day, destinations, run_id, failure_pct, closed_roads) do
      {:ok, _shipped} -> :ok
      {:error, :absent} -> Plant.hold(origin, volume, run_id)
    end
  end

  defp convoys(volume) when volume < @convoy_min_m3, do: []

  defp convoys(volume) do
    full = trunc(volume / @convoy_m3)
    leftover = volume - full * @convoy_m3
    loads = List.duplicate(@convoy_m3, full)

    cond do
      leftover >= @convoy_min_m3 -> loads ++ [leftover]
      full > 0 -> loads
      true -> [volume]
    end
  end

  defp reliefs(refineries) do
    needs = gaps(refineries, fn refinery -> refinery.planned_m3 - refinery.allocated_m3 end)
    supplies = gaps(refineries, fn refinery -> refinery.allocated_m3 - refinery.planned_m3 end)
    order = Enum.map(needs, &elem(&1, 0))
    match(supplies, needs, order, [])
  end

  defp gaps(refineries, gap) do
    refineries
    |> Enum.map(fn refinery -> {refinery.id, gap.(refinery)} end)
    |> Enum.filter(fn {_id, volume} -> volume > 0.0 end)
    |> Enum.sort_by(fn {id, volume} -> {-volume, id} end)
  end

  defp match([{origin, slack} | supplies], [{destination, gap} | needs], order, acc) do
    volume = min(slack, gap)

    match(
      rest(supplies, origin, slack - volume),
      rest(needs, destination, gap - volume),
      order,
      [{origin, volume, destinations(destination, order)} | acc]
    )
  end

  defp match(_supplies, _needs, _order, acc), do: Enum.reverse(acc)

  defp rest(rows, id, left) when left > 0.0, do: [{id, left} | rows]
  defp rest(rows, _id, _left), do: rows

  defp destinations(destination, order), do: [destination | List.delete(order, destination)]
end
