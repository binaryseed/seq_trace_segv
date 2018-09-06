defmodule NewRelic.Harvest.Supervisor do
  use Supervisor
  alias NewRelic.Harvest.Collector

  @moduledoc """
    Harvest processes
      * Collector
  """

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    children = [
      worker(Collector.HarvesterStore, []),
      supervisor(Task.Supervisor, [[name: Collector.TaskSupervisor]]),
      supervisor(Collector.Supervisor, [])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
