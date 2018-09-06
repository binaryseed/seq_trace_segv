defmodule CollectorTest do
  use ExUnit.Case
  alias NewRelic.Harvest.Collector

  defmodule EvilCollectorPlug do
    import Plug.Conn

    def init(options), do: options

    def call(conn, test_pid: test_pid) do
      send(test_pid, :attempt)
      send_resp(conn, 503, ':(')
    end
  end

  setup do
    GenServer.call(Collector.AgentRun, :connected)
    :ok
  end

  test "Stores needed connect data" do
    assert Collector.AgentRun.account_id()
    assert Collector.AgentRun.primary_application_id()
  end

  test "Retry on 503" do
    {:ok, _} = Plug.Adapters.Cowboy2.http(EvilCollectorPlug, [test_pid: self()], port: 8881)

    TestHelper.with_temp_env(
      %{collector_instance_host: "localhost", port: 8881, scheme: "http"},
      fn ->
        assert Collector.Protocol.metric_data([123, 0, 1, []]) == 503
        assert_received(:attempt)
        assert_received(:attempt)
      end
    )
  end

  test "connects to proper collector host" do
    %{"redirect_host" => redirect_host} = Collector.Protocol.preconnect()
    assert redirect_host =~ "staging-collector-"
  end

  test "handles invalid license key" do
    prev = System.get_env("NEWRELIC_LICENSE_KEY") || Application.get_env(:new_relic, :license_key)

    System.put_env("NEWRELIC_LICENSE_KEY", "invalid_key")
    assert {:error, :license_exception} = Collector.Protocol.preconnect()

    prev && System.put_env("NEWRELIC_LICENSE_KEY", prev)
  end

  test "Agent restart ability" do
    GenServer.call(Collector.AgentRun, :connected)
    original_agent_run_id = Collector.AgentRun.agent_run_id()

    Application.stop(:new_relic)
    Application.start(:new_relic)

    GenServer.call(Collector.AgentRun, :connected)
    new_agent_run_id = Collector.AgentRun.agent_run_id()

    assert original_agent_run_id != new_agent_run_id
  end
end
