defmodule NewRelic.Harvest.Collector.ErrorTrace.Harvester do
  use GenServer

  alias NewRelic.Harvest.Collector
  alias NewRelic.Error.Trace

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
       error_traces: []
     }}
  end

  # API

  def report_error(%Trace{} = trace),
    do:
      Collector.ErrorTrace.HarvestCycle
      |> Collector.HarvestCycle.current_harvester()
      |> GenServer.cast({:report, trace})

  def gather_harvest,
    do:
      Collector.ErrorTrace.HarvestCycle
      |> Collector.HarvestCycle.current_harvester()
      |> GenServer.call(:gather_harvest)

  def complete(nil), do: :ignore

  def complete(harvester) do
    Task.Supervisor.start_child(Collector.ErrorTrace.TaskSupervisor, fn ->
      GenServer.call(harvester, :send_harvest)
      Supervisor.terminate_child(Collector.ErrorTrace.HarvesterSupervisor, harvester)
    end)
  end

  # Server

  def handle_cast({:report, _late_msg}, :completed), do: {:noreply, :completed}

  def handle_cast({:report, trace}, state) do
    state =
      state
      |> store_error(trace)

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

  def store_error(state, trace), do: %{state | error_traces: [trace | state.error_traces]}

  def send_harvest(state) do
    errors = build_payload(state)
    Collector.Protocol.error([Collector.AgentRun.agent_run_id(), errors])
    log_harvest(length(errors))
  end

  def log_harvest(harvest_size) do
    NewRelic.report_metric({:supportability, ErrorTrace}, harvest_size: harvest_size)
    NewRelic.log(:info, "Completed Error Trace harvest - size: #{harvest_size}")
  end

  def build_payload(state), do: state.error_traces |> Enum.uniq() |> Trace.format_errors()
end
