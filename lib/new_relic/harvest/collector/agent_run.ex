defmodule NewRelic.Harvest.Collector.AgentRun do
  use GenServer
  alias NewRelic.Harvest.Collector

  @moduledoc """
    This GenServer is responsible for connecting to the collector,
    and holding onto the Agent Run ID
  """

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    :ets.new(__MODULE__, [:named_table, :public, :set])

    if NewRelic.Config.configured?() do
      case Collector.Protocol.preconnect() do
        {:error, :license_exception} ->
          :ignore

        %{"redirect_host" => redirect_host} ->
          Application.put_env(:new_relic, :collector_instance_host, redirect_host)
          send(self(), :connect)
      end
    end

    {:ok, :unknown}
  end

  def agent_run_id, do: lookup(:agent_run_id)
  def trusted_account_key, do: lookup(:trusted_account_key)
  def account_id, do: lookup(:account_id)
  def primary_application_id, do: lookup(:primary_application_id)

  def reconnect, do: send(__MODULE__, :connect)

  def handle_info(:connect, _state) do
    state =
      connect_payload()
      |> Collector.Protocol.connect()
      |> parse_connect

    store(:agent_run_id, state["agent_run_id"])
    store(:trusted_account_key, state["trusted_account_key"])
    store(:account_id, state["account_id"])
    store(:primary_application_id, state["primary_application_id"])

    {:noreply, state}
  end

  def handle_call(:connected, _from, state) do
    {:reply, true, state}
  end

  defp connect_payload,
    do: [
      %{
        pid: NewRelic.Util.pid(),
        host: NewRelic.Util.hostname(),
        app_name: [NewRelic.Config.app_name()],
        language: "sdk",
        # environment: [["key", "value"], ["key", "value"]],
        agent_version: NewRelic.Config.agent_version()
      }
    ]

  defp parse_connect(
         %{"agent_run_id" => _, "messages" => [%{"message" => message}]} = connect_response
       ) do
    NewRelic.log(:info, message)
    connect_response
  end

  defp parse_connect(%{"error_type" => _, "message" => message}) do
    NewRelic.log(:error, message)
    :error
  end

  defp parse_connect(503) do
    NewRelic.log(:error, "Collector unavailable")
    :error
  end

  def store(key, value) do
    :ets.insert(__MODULE__, {key, value})
  end

  def lookup(key) do
    case :ets.lookup(__MODULE__, key) do
      [{^key, value}] -> value
      [] -> nil
    end
  end
end
