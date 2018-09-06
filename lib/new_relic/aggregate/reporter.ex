defmodule NewRelic.Aggregate.Reporter do
  use GenServer
  alias NewRelic.Aggregate

  @moduledoc """
  This GenServer collects aggregate metric measurements, aggregates them,
  and reports them to the Harvester at the defined sample_cycle
  """

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    if NewRelic.Config.enabled?(), do: send(self(), :report)
    {:ok, %{}}
  end

  def aggregate(meta, values), do: GenServer.cast(__MODULE__, {:aggregate, meta, values})

  def handle_cast({:aggregate, meta, values}, state) do
    metric =
      state
      |> Map.get(meta, %Aggregate{meta: meta})
      |> Aggregate.merge(values)

    {:noreply, Map.put(state, meta, metric)}
  end

  def handle_info(:report, state) do
    record_aggregates(state)
    Process.send_after(self(), :report, NewRelic.Config.sample_cycle())
    {:noreply, %{}}
  end

  def handle_call(:report, _from, state) do
    record_aggregates(state)
    {:reply, :ok, %{}}
  end

  def record_aggregates(state) do
    Enum.map(state, fn {_meta, metric} ->
      NewRelic.record(:Metric, Aggregate.annotate(metric))
    end)
  end
end
