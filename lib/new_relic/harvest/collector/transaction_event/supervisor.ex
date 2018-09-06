defmodule NewRelic.Harvest.Collector.TransactionEvent.Supervisor do
  use Supervisor
  alias NewRelic.Harvest.Collector

  @moduledoc """
    Transaction Event Harvester processes
  """

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    children = [
      supervisor(Collector.TransactionEvent.HarvesterSupervisor, []),
      supervisor(Task.Supervisor, [[name: Collector.TransactionEvent.TaskSupervisor]]),
      worker(Collector.HarvestCycle, [
        [
          name: Collector.TransactionEvent.HarvestCycle,
          module: Collector.TransactionEvent.Harvester,
          supervisor: Collector.TransactionEvent.HarvesterSupervisor
        ]
      ])
    ]

    supervise(children, strategy: :one_for_one)
  end
end

defmodule NewRelic.Harvest.Collector.TransactionEvent.HarvesterSupervisor do
  use Supervisor
  alias NewRelic.Harvest.Collector

  @moduledoc """
    Manages the individual Transaction Event Harvester processes
  """

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    children = [
      worker(Collector.TransactionEvent.Harvester, [])
    ]

    supervise(children, strategy: :simple_one_for_one, restart: :temporary, max_restarts: 10)
  end
end
