defmodule NewRelic.Harvest.Collector.Supervisor do
  use Supervisor
  alias NewRelic.Harvest.Collector

  @moduledoc """
    Collector Harvest Processes
  """

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    children = [
      worker(Collector.AgentRun, []),
      supervisor(Collector.Metric.Supervisor, []),
      supervisor(Collector.TransactionTrace.Supervisor, []),
      supervisor(Collector.TransactionEvent.Supervisor, []),
      supervisor(Collector.ErrorTrace.Supervisor, []),
      supervisor(Collector.TransactionErrorEvent.Supervisor, []),
      supervisor(Collector.CustomEvent.Supervisor, []),
      supervisor(Collector.SpanEvent.Supervisor, [])
    ]

    supervise(children, strategy: :one_for_all)
  end
end
