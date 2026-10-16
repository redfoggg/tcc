defmodule GasolineSimulator.Refineries.Logistics do
  alias GasolineSimulator.Data.Regions
  alias GasolineSimulator.Refineries.Plant

  def landed(ids, day, run_id) do
    Enum.reduce(ids, {[], 0.0, %{}, %{}}, fn id, {present, volume, by_region, by_plant} ->
      case Plant.arrivals(id, day, run_id) do
        {:ok, arrived} ->
          region = Regions.of_plant(id)

          {[id | present], volume + arrived, Map.update(by_region, region, arrived, &(&1 + arrived)),
           Map.put(by_plant, id, arrived)}

        {:error, :absent} ->
          {present, volume, by_region, by_plant}
      end
    end)
    |> then(fn {present, volume, by_region, by_plant} ->
      {Enum.reverse(present), volume, by_region, by_plant}
    end)
  end

  @convoy_m3 30.0
  @convoy_min_m3 20.0

  def dispatch(result, day, present, run_id, failure_pct \\ %{}, closed_roads \\ MapSet.new(), landed_by_plant \\ %{}) do
    shipped =
      result.refineries
      |> Enum.filter(&(&1.id in present))
      |> regional_reliefs(result.demand_m3, run_id, landed_by_plant)
      |> Enum.reduce({0.0, %{}}, fn {origin, volume, destinations}, {total, by_region} ->
        sent = place({origin, volume, destinations}, day, run_id, failure_pct, closed_roads)
        region = Regions.of_plant(origin)
        {total + sent, Map.update(by_region, region, sent, &(&1 + sent))}
      end)

    {result, shipped}
  end

  defp place({_origin, volume, _destinations}, _day, _run_id, _failure_pct, _closed_roads)
       when volume <= 0.0,
       do: 0.0

  defp place({origin, volume, destinations}, day, run_id, failure_pct, closed_roads) do
    volume
    |> convoys()
    |> Enum.sum_by(&ship_convoy(origin, &1, destinations, day, run_id, failure_pct, closed_roads))
  end

  defp ship_convoy(origin, volume, destinations, day, run_id, failure_pct, closed_roads) do
    case Plant.ship(origin, volume, day, destinations, run_id, failure_pct, closed_roads) do
      {:ok, shipped} -> shipped
      {:error, :absent} ->
        Plant.hold(origin, volume, run_id)
        0.0
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

  defp regional_reliefs(refineries, demand_m3, run_id, landed_by_plant) do
    grouped = Enum.group_by(refineries, &Regions.of_plant(&1.id))

    {supplies, needs} =
      Enum.reduce(Regions.ids(), {[], []}, fn region, {supplies, needs} ->
        plants = Map.get(grouped, region, [])
        held = Enum.sum_by(plants, &on_hand(&1.id, run_id))
        arrived = Enum.sum_by(plants, &Map.get(landed_by_plant, &1.id, 0.0))
        local = max(held - arrived, 0.0)
        refined = Enum.sum_by(plants, & &1.allocated_m3)
        demand = Regions.demand(demand_m3, region)

        cond do
          plants == [] -> {supplies, needs}
          refined < demand ->
            {supplies, needs ++ shares(plants, demand - refined, & &1.processing_capacity_m3)}

          local > demand ->
            {supplies ++ shares(plants, local - demand, &on_hand(&1.id, run_id)), needs}

          true ->
            {supplies, needs}
        end
      end)

    supplies = Enum.sort_by(supplies, fn {id, volume} -> {-volume, id} end)
    needs = Enum.sort_by(needs, fn {id, volume} -> {-volume, id} end)
    match(supplies, needs, Enum.map(needs, &elem(&1, 0)), [])
  end

  defp shares(_plants, volume, _weight) when volume <= 0.0, do: []

  defp shares(plants, volume, weight) do
    total = Enum.sum_by(plants, weight)

    if total <= 0.0 do
      []
    else
      plants
      |> Enum.map(fn plant -> {plant.id, volume * weight.(plant) / total} end)
      |> Enum.filter(fn {_id, part} -> part > 0.0 end)
    end
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

  defp on_hand(id, run_id) do
    case Plant.on_hand(id, run_id) do
      {:ok, volume} -> volume
      {:error, :absent} -> 0.0
    end
  end
end
