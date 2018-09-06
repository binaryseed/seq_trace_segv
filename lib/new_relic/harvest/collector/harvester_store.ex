defmodule NewRelic.Harvest.Collector.HarvesterStore do
  use GenServer

  @moduledoc """
    Wrapper around an ETS table that tracks the current process for a given harvester
  """

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    :ets.new(__MODULE__, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{}}
  end

  def current(harvester) do
    case :ets.lookup(__MODULE__, harvester) do
      [{^harvester, pid}] -> pid
      _ -> nil
    end
  end

  def update(harvester, pid) do
    :ets.insert(__MODULE__, {harvester, pid})
  end
end
