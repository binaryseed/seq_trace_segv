defmodule NewRelic.Harvest.Collector.SpanEvent.Supervisor do
  use Supervisor
  alias NewRelic.Harvest.Collector

  @moduledoc """
    Span Event Harvester processes
  """

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    children = [
      supervisor(Collector.SpanEvent.HarvesterSupervisor, []),
      supervisor(Task.Supervisor, [[name: Collector.SpanEvent.TaskSupervisor]]),
      worker(Collector.HarvestCycle, [
        [
          name: Collector.SpanEvent.HarvestCycle,
          module: Collector.SpanEvent.Harvester,
          supervisor: Collector.SpanEvent.HarvesterSupervisor
        ]
      ])
    ]

    supervise(children, strategy: :one_for_one)
  end
end

defmodule NewRelic.Harvest.Collector.SpanEvent.HarvesterSupervisor do
  use Supervisor
  alias NewRelic.Harvest.Collector

  @moduledoc """
    Manages the individual Span Event Harvester processes
  """

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    children = [
      worker(Collector.SpanEvent.Harvester, [])
    ]

    supervise(children, strategy: :simple_one_for_one, restart: :temporary, max_restarts: 10)
  end
end
