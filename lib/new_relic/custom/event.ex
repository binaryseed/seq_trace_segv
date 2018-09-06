defmodule NewRelic.Custom.Event do
  @moduledoc """
  Custom event data structure
  """

  defstruct type: nil,
            timestamp: nil,
            attributes: %{}

  def format_custom_events(events) do
    Enum.map(events, &format_custom_event/1)
  end

  def format_custom_event(%__MODULE__{} = event) do
    [
      %{
        type: event.type,
        timestamp: event.timestamp
      },
      NewRelic.Util.Event.process_event(event.attributes),
      %{}
    ]
  end
end
