defmodule NewRelic.Sampler.Ets do
  use GenServer
  @kb 1024
  @word_size :erlang.system_info(:wordsize)

  @moduledoc """
    Takes samples of the state of requested ETS tables
  """

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    if NewRelic.Config.enabled?(), do: send(self(), :report)
    {:ok, %{}}
  end

  def handle_info(:report, state) do
    record_sample()
    Process.send_after(self(), :report, NewRelic.Config.sample_cycle())
    {:noreply, state}
  end

  def handle_call(:report, _from, state) do
    record_sample()
    {:reply, :ok, state}
  end

  def record_sample, do: Enum.map(named_tables(), &record_sample/1)

  @sample_threshold 500
  def record_sample(table) do
    case take_sample(table) do
      :undefined -> :ignore
      %{size: size} when size < @sample_threshold -> :ignore
      stat -> NewRelic.record(:EtsStat, stat)
    end
  end

  def named_tables, do: Enum.reject(:ets.all(), &is_reference/1)

  defp take_sample(table) do
    with words when is_number(words) <- :ets.info(table, :memory),
         size when is_number(size) <- :ets.info(table, :size) do
      %{table_name: inspect(table), memory_kb: round(words * @word_size) / @kb, size: size}
    else
      :undefined -> :undefined
    end
  end
end
