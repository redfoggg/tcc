defmodule GasolineSimulator.Refineries.Plant do
  use GenServer

  alias GasolineSimulator.Models.Problem
  alias GasolineSimulator.Refineries.Delivery
  alias GasolineSimulator.Refineries.DeliverySupervisor
  alias GasolineSimulator.Refineries.Distances
  alias GasolineSimulator.Scenarios.Seed

  @registry GasolineSimulator.Refineries.Registry
  @consecutive_loss_limit 3
  @route_pause_days 10
  @failure_scale 100
  @ratio_step 0.01

  def child_spec(attrs) do
    %{
      id: attrs.id,
      start: {__MODULE__, :start_link, [attrs]},
      restart: :temporary
    }
  end

  def start_link(attrs) do
    GenServer.start_link(__MODULE__, attrs, name: via(key(attrs)))
  end

  def arrivals(id, day, run_id), do: call({run_id, id}, {:arrivals, day})

  def ship(id, volume, day, peer_ids, run_id, failure_pct, closed_roads) do
    call({run_id, id}, {:ship, volume, day, peer_ids, failure_pct, closed_roads})
  end

  def consecutive_loss_limit, do: @consecutive_loss_limit

  def route_pause_days, do: @route_pause_days

  def credit(id, volume, run_id) when volume > 0.0 do
    call({run_id, id}, {:credit, volume})
  end

  def credit(_id, _volume, _run_id), do: :ok

  def draw(id, volume, run_id), do: call({run_id, id}, {:draw, volume})

  def on_hand(id, run_id), do: call({run_id, id}, :on_hand)

  def lost_m3(id, run_id), do: call({run_id, id}, :lost_m3)

  def open_run(id, run_id, burst, sustainable) do
    call({run_id, id}, {:open_run, burst, sustainable})
  end

  def rejoin(id, run_id), do: call({run_id, id}, :rejoin)

  def floor_ratio(id, run_id) do
    case call({run_id, id}, :floor_ratio) do
      {:error, :absent} -> Problem.sustainable_utilization_ratio()
      ratio -> ratio
    end
  end

  def hear(id, report), do: call({report.run_id, id}, {:hear, report})

  def pid(id, run_id), do: pid({run_id, id})

  def pid(key) do
    case Registry.lookup(@registry, key) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  @impl true
  def init(attrs) do
    Seed.plant(Map.get(attrs, :seed), {:plant, Map.get(attrs, :seed_path), attrs.id})

    {:ok,
     %{
       id: attrs.id,
       run: Map.get(attrs, :run),
       deliveries: Map.get(attrs, :deliveries),
       observed: Map.get(attrs, :observed, false),
       on_hand: 0.0,
       outgoing: [],
       expected: [],
       routes: %{},
       lost_m3: 0.0,
       pace: nil,
       sustainable: nil
     }}
  end

  @impl true
  def handle_call({:open_run, _burst, sustainable}, _from, state) do
    {:reply, :ok, %{state | pace: state.pace || open_pace(sustainable), sustainable: sustainable}}
  end

  def handle_call(:rejoin, _from, state) do
    {:reply, :ok, %{state | pace: ramp_pace()}}
  end

  def handle_call(:floor_ratio, _from, state) do
    ratio = if state.pace.phase == :ramping, do: state.pace.ratio, else: state.sustainable
    {:reply, ratio, state}
  end

  def handle_call({:hear, report}, _from, state) do
    pace =
      if report.deficit_m3 <= 1.0 and state.pace.phase == :ramping do
        climb_ramp(state.pace, state.sustainable)
      else
        state.pace
      end

    {:reply, :ok, %{state | pace: pace}}
  end

  def handle_call({:credit, volume}, _from, state) do
    {:reply, :ok, %{state | on_hand: state.on_hand + volume}}
  end

  def handle_call({:draw, volume}, _from, state) do
    {:reply, :ok, %{state | on_hand: state.on_hand - min(volume, state.on_hand)}}
  end

  def handle_call(:on_hand, _from, state) do
    {:reply, {:ok, state.on_hand}, state}
  end

  def handle_call(:lost_m3, _from, state) do
    {:reply, {:ok, state.lost_m3}, state}
  end

  def handle_call({:arrivals, day}, _from, state) do
    {due, later} = Enum.split_with(state.expected, &(not Date.after?(&1.arrival, day)))

    volume =
      Enum.reduce(due, 0.0, fn delivery, acc ->
        case Delivery.claim(delivery.pid, day) do
          {:ok, amount} -> acc + amount
          {:error, :absent} -> acc
        end
      end)

    {:reply, {:ok, volume}, %{state | expected: later}}
  end

  def handle_call({:ship, volume, day, peer_ids, failure_pct, closed_roads}, _from, state) do
    volume = min(volume, state.on_hand)

    if volume <= 0.0 do
      {:reply, {:ok, 0.0}, state}
    else
      case deliver(state, volume, day, peers_of(state.id, peer_ids), failure_pct, closed_roads) do
        {:ok, state} -> {:reply, {:ok, volume}, state}
        :unclaimed -> {:reply, {:error, :absent}, state}
      end
    end
  end

  @impl true
  def handle_cast({:track, delivery}, state) do
    Process.monitor(delivery.pid)
    {:noreply, %{state | expected: [delivery | state.expected]}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, signal(state, pid)}
  end

  defp signal(state, pid) do
    %{
      state
      | outgoing: Enum.reject(state.outgoing, &(&1.pid == pid)),
        expected: Enum.reject(state.expected, &(&1.pid == pid))
    }
  end

  defp open_pace(sustainable) do
    %{phase: :open, ratio: sustainable}
  end

  defp ramp_pace do
    %{phase: :ramping, ratio: Problem.min_utilization_ratio()}
  end

  defp climb_ramp(%{ratio: ratio} = pace, sustainable) do
    nxt = min(ratio + @ratio_step, sustainable)

    if nxt + 1.0e-12 >= sustainable do
      open_pace(sustainable)
    else
      %{pace | ratio: nxt}
    end
  end

  defp arrival_on(day, origin, destination) do
    Date.add(day, Distances.transit_days(origin, destination))
  end

  defp peers_of(id, peer_ids) do
    peer_ids
    |> Enum.reject(&(&1 == id))
    |> Enum.uniq()
  end

  defp deliver(_state, _volume, _day, [], _failure_pct, _closed_roads), do: :unclaimed

  defp deliver(state, volume, day, [peer | rest], failure_pct, closed_roads) do
    if route_paused?(state, peer, day) or road_closed?(state.id, peer, closed_roads) do
      deliver(state, volume, day, rest, failure_pct, closed_roads)
    else
      attrs = %{
        origin_id: state.id,
        destination_id: peer,
        volume_m3: volume,
        arrival: arrival_on(day, state.id, peer),
        run_id: state.run,
        observed: state.observed
      }

      case DeliverySupervisor.start_delivery(state.deliveries, attrs) do
        {:ok, pid, id} ->
          delivery = Map.merge(attrs, %{id: id, pid: pid})

          case cast({state.run, peer}, {:track, delivery}) do
            :ok ->
              Process.monitor(pid)

              state = %{
                state
                | on_hand: state.on_hand - volume,
                  outgoing: [delivery | state.outgoing]
              }

              if cargo_lost?(failure_pct, state.id, peer) do
                DeliverySupervisor.fail(state.deliveries, pid)
                {:ok, note_loss(state, peer, day, volume)}
              else
                {:ok, note_success(state, peer)}
              end

            {:error, :absent} ->
              GenServer.stop(pid, :normal)
              deliver(state, volume, day, rest, failure_pct, closed_roads)
          end

        _other ->
          deliver(state, volume, day, rest, failure_pct, closed_roads)
      end
    end
  end

  defp cargo_lost?(failure_pct, origin, destination) do
    pct = route_pct(failure_pct, origin, destination)
    pct > 0 and :rand.uniform(@failure_scale) <= pct
  end

  defp route_pct(failure_pct, origin, destination) do
    Map.fetch!(failure_pct, {origin, destination})
  end

  defp route_paused?(state, destination, day) do
    case route_of(state, destination) do
      %{resume_on: %Date{} = resume_on} -> Date.compare(day, resume_on) == :lt
      _ -> false
    end
  end

  defp road_closed?(origin, destination, closed_roads) do
    MapSet.member?(closed_roads, Distances.pair(origin, destination))
  end

  defp note_loss(state, destination, day, volume) do
    route = route_of(state, destination)
    losses = route.losses + 1

    resume_on =
      if losses >= @consecutive_loss_limit do
        Date.add(day, @route_pause_days)
      else
        route.resume_on
      end

    %{state | lost_m3: state.lost_m3 + volume}
    |> put_route(destination, %{losses: losses, resume_on: resume_on})
  end

  defp note_success(state, destination) do
    put_route(state, destination, %{losses: 0, resume_on: nil})
  end

  defp route_of(state, destination) do
    Map.get(state.routes, destination, %{losses: 0, resume_on: nil})
  end

  defp put_route(state, destination, route) do
    %{state | routes: Map.put(state.routes, destination, route)}
  end

  defp call(key, message) do
    case pid(key) do
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

  defp cast(key, message) do
    case pid(key) do
      nil -> {:error, :absent}
      pid -> GenServer.cast(pid, message)
    end
  end

  defp key(%{run: run, id: id}) when not is_nil(run), do: {run, id}
  defp key(%{id: id}), do: id

  defp via(key), do: {:via, Registry, {@registry, key}}
end
