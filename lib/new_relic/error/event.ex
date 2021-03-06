defmodule NewRelic.Error.Event do
  @moduledoc """
  Error event data structure
  """

  defstruct type: "TransactionError",
            timestamp: nil,
            error_class: nil,
            error_message: nil,
            expected: false,
            transaction_name: nil,
            duration: nil,
            queue_duration: nil,
            database_duration: nil,
            http_response_code: nil,
            request_method: nil,
            user_attributes: %{}

  def format_errors(errors) do
    Enum.map(errors, &format_error/1)
  end

  def format_error(%__MODULE__{} = error) do
    [
      _intrinsic_attributes = %{
        type: error.type,
        timestamp: error.timestamp,
        "error.class": error.error_class,
        "error.message": error.error_message,
        "error.expected": error.expected,
        transactionName: error.transaction_name,
        duration: error.duration,
        queueDuration: error.queue_duration,
        databaseDuration: error.database_duration
      },
      NewRelic.Util.Event.process_event(error.user_attributes),
      _agent_attributes = %{
        httpResponseCode: error.http_response_code,
        "request.headers.method": error.request_method
      }
    ]
  end
end
