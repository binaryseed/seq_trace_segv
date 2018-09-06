defmodule NewRelic.Harvest.Collector.CustomEvent.Harvester do
  use GenServer

  alias NewRelic.Harvest.Collector
  alias NewRelic.Custom.Event

  @moduledoc """
    Individual Harvester process. Collects events for a single harvest cycle.
  """

  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    {:ok,
     %{
       start_time: System.system_time(),
       start_time_mono: System.monotonic_time(),
       end_time_mono: nil,
       sampling: %{reservoir_size: NewRelic.Config.reservoir_size(__MODULE__), events_seen: 0},
       custom_events: []
     }}
  end

  # API

  def report_custom_event(type, attributes),
    do:
      report_custom_event(%Event{
        type: type,
        attributes: annotate(attributes),
        timestamp: System.system_time(:milliseconds) / 1_000
      })

  def report_custom_event(%Event{} = event),
    do:
      Collector.CustomEvent.HarvestCycle
      |> Collector.HarvestCycle.current_harvester()
      |> GenServer.cast({:report, event})

  def gather_harvest,
    do:
      Collector.CustomEvent.HarvestCycle
      |> Collector.HarvestCycle.current_harvester()
      |> GenServer.call(:gather_harvest)

  def complete(nil), do: :ignore

  def complete(harvester) do
    Task.Supervisor.start_child(Collector.CustomEvent.TaskSupervisor, fn ->
      GenServer.call(harvester, :send_harvest)
      Supervisor.terminate_child(Collector.CustomEvent.HarvesterSupervisor, harvester)
    end)
  end

  # Server

  def handle_cast({:report, _late_msg}, :completed), do: {:noreply, :completed}

  def handle_cast({:report, event}, state) do
    state =
      state
      |> store_event(event)
      |> store_sampling

    {:noreply, state}
  end

  def handle_call(:send_harvest, _from, :completed), do: {:reply, :completed, :completed}

  def handle_call(:send_harvest, _from, state) do
    send_harvest(%{state | end_time_mono: System.monotonic_time()})
    {:reply, :ok, :completed}
  end

  def handle_call(:gather_harvest, _from, :completed), do: {:reply, :completed, :completed}

  def handle_call(:gather_harvest, _from, state) do
    {:reply, build_payload(state), state}
  end

  # Helpers

  def annotate(event) do
    event
    |> Map.merge(NewRelic.Config.automatic_attributes())
  end

  def store_event(%{sampling: %{events_seen: seen, reservoir_size: size}} = state, event)
      when seen < size,
      do: %{state | custom_events: [event | state.custom_events]}

  def store_event(state, _event), do: state

  def store_sampling(%{sampling: sampling} = state),
    do: %{state | sampling: Map.update!(sampling, :events_seen, &(&1 + 1))}

  def send_harvest(state) do
    events = build_payload(state)
    Collector.Protocol.custom_event([Collector.AgentRun.agent_run_id(), state.sampling, events])
    log_harvest(length(events))
  end

  def log_harvest(harvest_size) do
    NewRelic.report_metric({:supportability, CustomEvent}, harvest_size: harvest_size)
    NewRelic.log(:info, "Completed Custom Event harvest - size: #{harvest_size}")
  end

  def build_payload(state), do: Event.format_custom_events(state.custom_events)
end
