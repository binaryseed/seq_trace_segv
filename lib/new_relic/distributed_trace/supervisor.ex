defmodule NewRelic.DistributedTrace.Supervisor do
  use Supervisor

  @moduledoc """
  Supervisor for Distributed Traces
  """

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    children = [
      worker(NewRelic.DistributedTrace.Tracker, [])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
