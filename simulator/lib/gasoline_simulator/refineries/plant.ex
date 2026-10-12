defmodule GasolineSimulator.Refineries.Plant do
  use GenServer

  alias GasolineSimulator.Models.Problem
  alias GasolineSimulator.Refineries.Delivery
  alias GasolineSimulator.Refineries.DeliverySupervisor
  alias GasolineSimulator.Refineries.Distances

  @registry GasolineSimulator.Refineries.Registry
  @consecutive_loss_limit 3
  @route_pause_days 10
  @failure_scale 100
  @default_failure_pct 1
  @ratio_step 0.01

  def child_spec(attrs) do
    %{
      id: attrs.id,
      start: {__MODULE__, :start_link, [attrs]},
      restart: :temporary
    }
  end

  def start_link(attrs) do
    GenServer.start_link(__MODULE__, attrs, name: via(attrs.id))
  end

  def arrivals(id, day, run_id), do: call(id, {:arrivals, day, run_id})

  def ship(id, volume, day, peer_ids, run_id, failure_pct \\ %{}, closed_roads \\ MapSet.new()) do
    call(id, {:ship, volume, day, peer_ids, run_id, failure_pct(failure_pct), closed_roads})
  end

  def failure_pct(values) when is_map(values) do
    Enum.reduce(values, %{}, fn {key, pct}, acc ->
      pct = clamp_failure_pct(pct)

      Enum.reduce(failure_keys(key), acc, fn failure_key, acc ->
        Map.put(acc, failure_key, pct)
      end)
    end)
  end

  def failure_pct(_values), do: %{}

  def consecutive_loss_limit, do: @consecutive_loss_limit

  def route_pause_days, do: @route_pause_days

  def default_failure_pct, do: @default_failure_pct

  def hold(id, volume, run_id), do: call(id, {:hold, volume, run_id})

  def credit(id, volume, run_id) when is_number(volume) and volume > 0.0 do
    call(id, {:credit, volume, run_id})
  end

  def credit(_id, _volume, _run_id), do: :ok

  def on_hand(id, run_id), do: call(id, {:on_hand, run_id})

  def notices(id), do: call(id, :notices)

  def fleet(id), do: call(id, :fleet)

  def open_run(id, run_id, burst, sustainable) do
    call(id, {:open_run, run_id, burst, sustainable})
  end

  def rejoin(id), do: call(id, :rejoin)

  def ratio(id) do
    case call(id, :ratio) do
      {:error, :absent} -> Problem.burst_utilization_ratio()
      ratio -> ratio
    end
  end

  def floor_ratio(id) do
    case call(id, :floor_ratio) do
      {:error, :absent} -> Problem.sustainable_utilization_ratio()
      ratio -> ratio
    end
  end

  def hear(id, report), do: call(id, {:hear, report})

  def reset(id, run_id), do: call(id, {:reset, run_id})

  def pid(id) do
    case Registry.lookup(@registry, id) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  @impl true
  def init(attrs) do
    {:ok,
     %{
       id: attrs.id,
       on_hand: %{},
       outgoing: %{},
       expected: %{},
       notices: [],
       routes: %{},
       fleet: nil,
       pace: nil,
       burst: nil,
       sustainable: nil
     }}
  end

  @impl true
  def handle_call({:reset, run_id}, _from, state) do
    {:reply, :ok,
     %{
       state
       | on_hand: Map.delete(state.on_hand, run_id),
         outgoing: Map.delete(state.outgoing, run_id),
         expected: Map.delete(state.expected, run_id),
         notices: Enum.reject(state.notices, &(&1.run_id == run_id)),
         routes: Map.delete(state.routes, run_id),
         fleet: clear_fleet(state.fleet, run_id),
         pace: clear_pace(state.pace, run_id),
         burst: nil,
         sustainable: nil
     }}
  end

  def handle_call({:open_run, run_id, burst, sustainable}, _from, state) do
    pace =
      case state.pace do
        %{run_id: ^run_id} = pace -> pace
        _ -> open_pace(sustainable, run_id)
      end

    {:reply, :ok, %{state | pace: pace, burst: burst, sustainable: sustainable}}
  end

  def handle_call(:rejoin, _from, state) do
    {:reply, :ok, %{state | pace: ramp_pace(state.pace.run_id)}}
  end

  def handle_call(:ratio, _from, state) do
    {:reply, state.pace.ratio, state}
  end

  def handle_call(:floor_ratio, _from, state) do
    ratio = if state.pace.phase == :ramping, do: state.pace.ratio, else: state.sustainable
    {:reply, ratio, state}
  end

  def handle_call({:hear, report}, _from, state) do
    heard = Map.take(report, [:run_id, :deficit_m3, :planned_m3])

    pace =
      if report.deficit_m3 <= 1.0 and state.pace.phase == :ramping do
        climb_ramp(state.pace, state)
      else
        state.pace
      end

    {:reply, :ok, %{state | pace: pace, fleet: heard}}
  end

  def handle_call(:fleet, _from, state) do
    {:reply, state.fleet, state}
  end

  def handle_call({:hold, _volume, _run_id}, _from, state) do
    {:reply, :ok, state}
  end

  def handle_call({:credit, volume, run_id}, _from, state) do
    {:reply, :ok, add_on_hand(state, run_id, volume)}
  end

  def handle_call({:on_hand, run_id}, _from, state) do
    {:reply, {:ok, Map.get(state.on_hand, run_id, 0.0)}, state}
  end

  def handle_call(:notices, _from, state) do
    {:reply, state.notices, state}
  end

  def handle_call({:arrivals, day, run_id}, _from, state) do
    waiting = Map.get(state.expected, run_id, [])
    {due, later} = Enum.split_with(waiting, &(not Date.after?(&1.arrival, day)))

    volume =
      Enum.reduce(due, 0.0, fn delivery, acc ->
        case Delivery.claim(delivery.pid, day) do
          {:ok, amount} -> acc + amount
          {:error, :absent} -> acc
        end
      end)

    {:reply, {:ok, volume}, put_list(state, :expected, run_id, later)}
  end

  def handle_call({:ship, volume, day, peer_ids, run_id, failure_pct, closed_roads}, _from, state) do
    case deliver(
           state,
           volume,
           day,
           peers_of(state.id, peer_ids),
           run_id,
           failure_pct,
           closed_roads
         ) do
      {:ok, state} -> {:reply, {:ok, volume}, state}
      :unclaimed -> {:reply, {:error, :absent}, state}
    end
  end

  def handle_call({:track, delivery}, _from, state) do
    Process.monitor(delivery.pid)
    {:reply, :ok, remember(state, :expected, delivery)}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    {:noreply, signal(state, pid, reason)}
  end

  defp signal(state, pid, :normal) do
    %{state | outgoing: drop_pid(state.outgoing, pid), expected: drop_pid(state.expected, pid)}
  end

  defp signal(state, pid, _reason) do
    {outgoing, sent} = take_pid(state.outgoing, pid)
    {expected, lost} = take_pid(state.expected, pid)

    %{
      state
      | outgoing: outgoing,
        expected: expected,
        notices: Enum.map(sent ++ lost, &notice/1) ++ state.notices
    }
  end

  defp notice(delivery) do
    %{
      kind: :lost,
      delivery_id: delivery.id,
      volume_m3: delivery.volume_m3,
      origin_id: delivery.origin_id,
      destination_id: delivery.destination_id,
      run_id: delivery.run_id
    }
  end

  defp clear_fleet(%{run_id: run_id}, run_id), do: nil
  defp clear_fleet(fleet, _run_id), do: fleet

  defp clear_pace(%{run_id: run_id}, run_id), do: nil
  defp clear_pace(pace, _run_id), do: pace

  defp open_pace(burst, run_id) do
    %{phase: :open, ratio: burst, surplus: 0.0, lock_left: 0, run_id: run_id}
  end

  defp ramp_pace(run_id) do
    %{
      phase: :ramping,
      ratio: Problem.min_utilization_ratio(),
      surplus: 0.0,
      lock_left: 0,
      run_id: run_id
    }
  end

  defp climb_ramp(%{ratio: ratio} = pace, state) do
    nxt = min(ratio + @ratio_step, state.sustainable)

    if nxt + 1.0e-12 >= state.sustainable do
      open_pace(state.sustainable, pace.run_id)
    else
      %{pace | ratio: nxt}
    end
  end

  defp add_on_hand(state, run_id, volume) do
    on_hand = Map.get(state.on_hand, run_id, 0.0) + volume
    %{state | on_hand: Map.put(state.on_hand, run_id, on_hand)}
  end

  defp debit_on_hand(state, run_id, volume) do
    on_hand = Map.get(state.on_hand, run_id, 0.0) - volume
    %{state | on_hand: Map.put(state.on_hand, run_id, on_hand)}
  end

  defp remember(state, field, delivery) do
    waiting = [delivery | Map.get(state, field) |> Map.get(delivery.run_id, [])]
    put_list(state, field, delivery.run_id, waiting)
  end

  defp drop_pid(groups, pid) do
    Map.new(groups, fn {run_id, deliveries} ->
      {run_id, Enum.reject(deliveries, &(&1.pid == pid))}
    end)
  end

  defp take_pid(groups, pid) do
    Enum.reduce(groups, {%{}, []}, fn {run_id, deliveries}, {kept, taken} ->
      {hit, rest} = Enum.split_with(deliveries, &(&1.pid == pid))
      {put_if_any(kept, run_id, rest), hit ++ taken}
    end)
  end

  defp put_if_any(groups, _run_id, []), do: groups
  defp put_if_any(groups, run_id, deliveries), do: Map.put(groups, run_id, deliveries)

  defp put_list(state, field, run_id, []) do
    Map.put(state, field, Map.delete(Map.get(state, field), run_id))
  end

  defp put_list(state, field, run_id, deliveries) do
    Map.put(state, field, Map.put(Map.get(state, field), run_id, deliveries))
  end

  defp arrival_on(day, origin, destination) do
    Date.add(day, Distances.transit_days(origin, destination))
  end

  defp peers_of(id, peer_ids) do
    peer_ids
    |> Enum.reject(&(&1 == id))
    |> Enum.uniq()
  end

  defp deliver(state, volume, _day, _peers, _run_id, _failure_pct, _closed_roads)
       when volume <= 0.0,
       do: {:ok, state}

  defp deliver(_state, _volume, _day, [], _run_id, _failure_pct, _closed_roads), do: :unclaimed

  defp deliver(state, volume, day, [peer | rest], run_id, failure_pct, closed_roads) do
    if route_paused?(state, peer, day, run_id) or road_closed?(state.id, peer, closed_roads) do
      deliver(state, volume, day, rest, run_id, failure_pct, closed_roads)
    else
      attrs = %{
        origin_id: state.id,
        destination_id: peer,
        volume_m3: volume,
        arrival: arrival_on(day, state.id, peer),
        run_id: run_id
      }

      case DeliverySupervisor.start_delivery(attrs) do
        {:ok, pid, id} ->
          delivery = Map.merge(attrs, %{id: id, pid: pid})

          case call(peer, {:track, delivery}) do
            :ok ->
              Process.monitor(pid)
              state = state |> debit_on_hand(run_id, volume) |> remember(:outgoing, delivery)

              if cargo_lost?(failure_pct, state.id, peer) do
                DeliverySupervisor.fail(id)
                {:ok, note_loss(state, peer, day, run_id)}
              else
                {:ok, note_success(state, peer, run_id)}
              end

            {:error, :absent} ->
              GenServer.stop(pid, :normal)
              deliver(state, volume, day, rest, run_id, failure_pct, closed_roads)
          end

        _other ->
          deliver(state, volume, day, rest, run_id, failure_pct, closed_roads)
      end
    end
  end

  defp cargo_lost?(failure_pct, origin, destination) do
    pct = route_pct(failure_pct, origin, destination)
    pct > 0 and :rand.uniform(@failure_scale) <= pct
  end

  defp route_pct(failure_pct, origin, destination) do
    pair = Distances.pair(origin, destination)
    label = Distances.pair_key(pair)

    raw =
      cond do
        Map.has_key?(failure_pct, pair) -> Map.fetch!(failure_pct, pair)
        Map.has_key?(failure_pct, label) -> Map.fetch!(failure_pct, label)
        Map.has_key?(failure_pct, destination) -> Map.fetch!(failure_pct, destination)
        true -> Map.get(failure_pct, to_string(destination), @default_failure_pct)
      end

    clamp_failure_pct(raw)
  end

  defp failure_keys({origin, destination}) do
    pair = Distances.pair(origin, destination)
    [pair, Distances.pair_key(pair)]
  end

  defp failure_keys([origin, destination]), do: failure_keys({origin, destination})

  defp failure_keys(key) when is_binary(key) do
    case String.split(key, "|", parts: 2) do
      [origin, destination] -> failure_keys({origin, destination})
      _ -> [key]
    end
  end

  defp failure_keys(key), do: [to_string(key)]

  defp clamp_failure_pct(pct) when is_integer(pct) do
    pct |> max(0) |> min(@failure_scale)
  end

  defp clamp_failure_pct(pct) when is_float(pct) do
    pct |> round() |> clamp_failure_pct()
  end

  defp clamp_failure_pct(pct) when is_binary(pct) do
    case Integer.parse(String.trim(pct)) do
      {number, ""} -> clamp_failure_pct(number)
      _ -> 0
    end
  end

  defp clamp_failure_pct(_pct), do: 0

  defp route_paused?(state, destination, day, run_id) do
    case route_of(state, run_id, destination) do
      %{resume_on: %Date{} = resume_on} -> Date.compare(day, resume_on) == :lt
      _ -> false
    end
  end

  defp road_closed?(origin, destination, closed_roads) do
    MapSet.member?(closed_roads, Distances.pair(origin, destination))
  end

  defp note_loss(state, destination, day, run_id) do
    route = route_of(state, run_id, destination)
    losses = route.losses + 1

    resume_on =
      if losses >= @consecutive_loss_limit do
        Date.add(day, @route_pause_days)
      else
        route.resume_on
      end

    put_route(state, run_id, destination, %{losses: losses, resume_on: resume_on})
  end

  defp note_success(state, destination, run_id) do
    put_route(state, run_id, destination, %{losses: 0, resume_on: nil})
  end

  defp route_of(state, run_id, destination) do
    state.routes
    |> Map.get(run_id, %{})
    |> Map.get(destination, %{losses: 0, resume_on: nil})
  end

  defp put_route(state, run_id, destination, route) do
    routes = Map.get(state.routes, run_id, %{})
    %{state | routes: Map.put(state.routes, run_id, Map.put(routes, destination, route))}
  end

  defp call(id, message) do
    case pid(id) do
      nil ->
        {:error, :absent}

      pid ->
        try do
          GenServer.call(pid, message)
        catch
          :exit, _reason -> {:error, :absent}
        end
    end
  end

  defp via(id), do: {:via, Registry, {@registry, id}}
end
