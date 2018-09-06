defmodule NewRelic.Transaction.ErrorHandler do
  @moduledoc """
    This macro injects a Plug.ErrorHandler that will ensure that requests that
      end in an error still get reported as Transaction Traces
  """

  defmacro __using__(_) do
    quote do
      use Plug.ErrorHandler

      def handle_errors(conn, error) do
        NewRelic.handle_errors(conn, error)
      end
    end
  end
end
