defmodule NewRelic.Harvest.Collector.TransactionTrace.Supervisor do
  use Supervisor
  alias NewRelic.Harvest.Collector

  @moduledoc """
    Transaction Trace Harvester processes
  """

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    children = [
      supervisor(Collector.TransactionTrace.HarvesterSupervisor, []),
      supervisor(Task.Supervisor, [[name: Collector.TransactionTrace.TaskSupervisor]]),
      worker(Collector.HarvestCycle, [
        [
          name: Collector.TransactionTrace.HarvestCycle,
          module: Collector.TransactionTrace.Harvester,
          supervisor: Collector.TransactionTrace.HarvesterSupervisor
        ]
      ])
    ]

    supervise(children, strategy: :one_for_one)
  end
end

defmodule NewRelic.Harvest.Collector.TransactionTrace.HarvesterSupervisor do
  use Supervisor
  alias NewRelic.Harvest.Collector

  @moduledoc """
    Manages the individual Transaction Trace Harvester processes
  """

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    children = [
      worker(Collector.TransactionTrace.Harvester, [])
    ]

    supervise(children, strategy: :simple_one_for_one, restart: :temporary, max_restarts: 10)
  end
end
