defmodule NewRelic.Harvest.Collector.TransactionErrorEvent.Harvester do
  use GenServer

  alias NewRelic.Harvest.Collector
  alias NewRelic.Error.Event

  @moduledoc """
    Individual Harvester process. Collects traces for a single harvest cycle.
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
       sampling: %{reservoir_size: 0, events_seen: 0},
       error_events: []
     }}
  end

  # API

  def report_error(%Event{} = event),
    do:
      Collector.TransactionErrorEvent.HarvestCycle
      |> Collector.HarvestCycle.current_harvester()
      |> GenServer.cast({:report, event})

  def gather_harvest,
    do:
      Collector.TransactionErrorEvent.HarvestCycle
      |> Collector.HarvestCycle.current_harvester()
      |> GenServer.call(:gather_harvest)

  def complete(nil), do: :ignore

  def complete(harvester) do
    Task.Supervisor.start_child(Collector.TransactionErrorEvent.TaskSupervisor, fn ->
      GenServer.call(harvester, :send_harvest)
      Supervisor.terminate_child(Collector.TransactionErrorEvent.HarvesterSupervisor, harvester)
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

  def store_event(state, event), do: %{state | error_events: [event | state.error_events]}

  def store_sampling(%{sampling: %{events_seen: n}} = state),
    do: %{state | sampling: %{events_seen: n + 1, reservoir_size: n + 1}}

  def send_harvest(state) do
    events = build_payload(state)
    Collector.Protocol.error_event([Collector.AgentRun.agent_run_id(), state.sampling, events])
    log_harvest(length(events))
  end

  def log_harvest(harvest_size) do
    NewRelic.report_metric({:supportability, TransactionErrorEvent}, harvest_size: harvest_size)
    NewRelic.log(:info, "Completed Error Event harvest - size: #{harvest_size}")
  end

  def build_payload(state), do: Event.format_errors(state.error_events)
end
