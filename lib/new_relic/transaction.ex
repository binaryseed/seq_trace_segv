defmodule NewRelic.Transaction do
  @moduledoc """
  Transaction reporting
  """

  defmacro __using__(_) do
    quote do
      plug(NewRelic.Transaction.Plug)
      plug(NewRelic.DistributedTrace.Plug)
      use NewRelic.Transaction.ErrorHandler
    end
  end
end
