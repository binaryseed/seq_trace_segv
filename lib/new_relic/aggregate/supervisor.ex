defmodule NewRelic.Aggregate.Supervisor do
  use Supervisor

  @moduledoc """
  Manages aggregate metric reporting process
  """

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    children = [
      worker(NewRelic.Aggregate.Reporter, [])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
