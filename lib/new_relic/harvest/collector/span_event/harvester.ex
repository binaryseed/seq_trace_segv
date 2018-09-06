defmodule NewRelic.Harvest.Collector.SpanEvent.Harvester do
  use GenServer

  alias NewRelic.DistributedTrace
  alias NewRelic.Harvest.Collector
  alias NewRelic.Span.Event

  @moduledoc """
    Individual Harvester process. Collects spans for a single harvest cycle.
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
       span_events: []
     }}
  end

  # API

  def report_span(
        timestamp_ms: timestamp_ms,
        duration_s: duration_s,
        name: name,
        mfa: mfa,
        category: category,
        attributes: attributes
      ) do
    context = DistributedTrace.get_tracing_context()

    report_span_event(context, mfa, %Event{
      timestamp: timestamp_ms,
      duration: duration_s,
      name: name,
      category: category,
      category_attributes: attributes
    })
  end

  def report_span_event(nil, _mfa, _event), do: :no_transaction
  def report_span_event(%DistributedTrace.Context{sampled: false}, _mfa, _event), do: :not_sampled

  def report_span_event(%DistributedTrace.Context{sampled: true} = context, mfa, %Event{} = event) do
    event
    |> Map.merge(%{
      guid: DistributedTrace.generate_guid(pid: self(), mfa: mfa),
      parent_id: DistributedTrace.generate_guid(pid: self()),
      trace_id: context.trace_id,
      transaction_id: context.guid,
      sampled: true,
      priority: context.priority
    })
    |> report_span_event()
  end

  def report_span_event(%Event{} = event),
    do:
      Collector.SpanEvent.HarvestCycle
      |> Collector.HarvestCycle.current_harvester()
      |> GenServer.cast({:report, event})

  def gather_harvest,
    do:
      Collector.SpanEvent.HarvestCycle
      |> Collector.HarvestCycle.current_harvester()
      |> GenServer.call(:gather_harvest)

  def complete(nil), do: :ignore

  def complete(harvester) do
    Task.Supervisor.start_child(Collector.SpanEvent.TaskSupervisor, fn ->
      GenServer.call(harvester, :send_harvest)
      Supervisor.terminate_child(Collector.SpanEvent.HarvesterSupervisor, harvester)
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

  def store_event(%{sampling: %{events_seen: seen, reservoir_size: size}} = state, event)
      when seen < size,
      do: %{state | span_events: [event | state.span_events]}

  def store_event(state, _event), do: state

  def store_sampling(%{sampling: sampling} = state),
    do: %{state | sampling: Map.update!(sampling, :events_seen, &(&1 + 1))}

  def send_harvest(state) do
    spans = build_payload(state)

    Collector.Protocol.span_event([
      Collector.AgentRun.agent_run_id(),
      state.sampling,
      spans
    ])

    log_harvest(length(spans))
  end

  def log_harvest(harvest_size) do
    NewRelic.report_metric({:supportability, SpanEvent}, harvest_size: harvest_size)
    NewRelic.log(:info, "Completed Span Event harvest - size: #{harvest_size}")
  end

  def build_payload(state), do: Event.format_spans(state.span_events)
end
