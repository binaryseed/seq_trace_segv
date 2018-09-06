defmodule NewRelic.Transaction.Event do
  @moduledoc """
    Transaction event data structure
  """

  defstruct type: "Transaction",
            web_duration: nil,
            database_duration: nil,
            timestamp: nil,
            name: nil,
            duration: nil,
            user_attributes: %{}

  def format_transactions(transactions) do
    Enum.map(transactions, &format_transaction/1)
  end

  def format_transaction(%__MODULE__{} = transaction) do
    [
      %{
        webDuration: transaction.web_duration,
        databaseDuration: transaction.database_duration,
        timestamp: transaction.timestamp,
        name: transaction.name,
        duration: transaction.duration,
        type: transaction.type
      },
      NewRelic.Util.Event.process_event(transaction.user_attributes)
    ]
  end
end
