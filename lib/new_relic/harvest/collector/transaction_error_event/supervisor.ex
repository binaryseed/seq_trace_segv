defmodule NewRelic.Harvest.Collector.TransactionErrorEvent.Supervisor do
  use Supervisor
  alias NewRelic.Harvest.Collector

  @moduledoc """
    Error Trace Harvester processes
  """

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    children = [
      supervisor(Collector.TransactionErrorEvent.HarvesterSupervisor, []),
      supervisor(Task.Supervisor, [[name: Collector.TransactionErrorEvent.TaskSupervisor]]),
      worker(Collector.HarvestCycle, [
        [
          name: Collector.TransactionErrorEvent.HarvestCycle,
          module: Collector.TransactionErrorEvent.Harvester,
          supervisor: Collector.TransactionErrorEvent.HarvesterSupervisor
        ]
      ])
    ]

    supervise(children, strategy: :one_for_one)
  end
end

defmodule NewRelic.Harvest.Collector.TransactionErrorEvent.HarvesterSupervisor do
  use Supervisor
  alias NewRelic.Harvest.Collector

  @moduledoc """
    Manages the individual Error Trace Harvester processes
  """

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    children = [
      worker(Collector.TransactionErrorEvent.Harvester, [])
    ]

    supervise(children, strategy: :simple_one_for_one, restart: :temporary, max_restarts: 10)
  end
end
