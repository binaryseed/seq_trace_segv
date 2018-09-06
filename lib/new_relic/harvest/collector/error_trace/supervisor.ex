defmodule NewRelic.Harvest.Collector.ErrorTrace.Supervisor do
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
      supervisor(Collector.ErrorTrace.HarvesterSupervisor, []),
      supervisor(Task.Supervisor, [[name: Collector.ErrorTrace.TaskSupervisor]]),
      worker(Collector.HarvestCycle, [
        [
          name: Collector.ErrorTrace.HarvestCycle,
          module: Collector.ErrorTrace.Harvester,
          supervisor: Collector.ErrorTrace.HarvesterSupervisor
        ]
      ])
    ]

    supervise(children, strategy: :one_for_one)
  end
end

defmodule NewRelic.Harvest.Collector.ErrorTrace.HarvesterSupervisor do
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
      worker(Collector.ErrorTrace.Harvester, [])
    ]

    supervise(children, strategy: :simple_one_for_one, restart: :temporary, max_restarts: 10)
  end
end
