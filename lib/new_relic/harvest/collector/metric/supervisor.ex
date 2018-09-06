defmodule NewRelic.Harvest.Collector.Metric.Supervisor do
  use Supervisor
  alias NewRelic.Harvest.Collector

  @moduledoc """
    Metric Harvester processes
  """

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    children = [
      supervisor(Collector.Metric.HarvesterSupervisor, []),
      supervisor(Task.Supervisor, [[name: Collector.Metric.TaskSupervisor]]),
      worker(Collector.HarvestCycle, [
        [
          name: Collector.Metric.HarvestCycle,
          module: Collector.Metric.Harvester,
          supervisor: Collector.Metric.HarvesterSupervisor
        ]
      ])
    ]

    supervise(children, strategy: :one_for_one)
  end
end

defmodule NewRelic.Harvest.Collector.Metric.HarvesterSupervisor do
  use Supervisor
  alias NewRelic.Harvest.Collector

  @moduledoc """
    Manages the individual Metric Harvester processes
  """

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    children = [
      worker(Collector.Metric.Harvester, [])
    ]

    supervise(children, strategy: :simple_one_for_one, restart: :temporary, max_restarts: 10)
  end
end
