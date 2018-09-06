defmodule NewRelic.Harvest.Collector.CustomEvent.Supervisor do
  use Supervisor
  alias NewRelic.Harvest.Collector

  @moduledoc """
    Custom Event Harvester processes
  """

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    children = [
      supervisor(Collector.CustomEvent.HarvesterSupervisor, []),
      supervisor(Task.Supervisor, [[name: Collector.CustomEvent.TaskSupervisor]]),
      worker(Collector.HarvestCycle, [
        [
          name: Collector.CustomEvent.HarvestCycle,
          module: Collector.CustomEvent.Harvester,
          supervisor: Collector.CustomEvent.HarvesterSupervisor
        ]
      ])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
