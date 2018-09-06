defmodule NewRelic.Error.Supervisor do
  use Supervisor

  @moduledoc """
    Registers an erlang error logger to catch and report errors.
  """

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    children = [
      supervisor(Task.Supervisor, [[name: NewRelic.Error.TaskSupervisor]])
    ]

    :logger.add_handler(:nr, NewRelic.Error.Logger, %{})
    supervise(children, strategy: :one_for_one)
  end
end
