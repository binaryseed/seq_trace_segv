defmodule LoggerTest do
  use ExUnit.Case

  test "memory Logger" do
    previous_logger = GenServer.call(NewRelic.Logger, {:logger, :memory})

    try do
      NewRelic.log(:warn, "OH_NO!")

      log = GenServer.call(NewRelic.Logger, :flush)
      assert log =~ "[WARN]"
      assert log =~ "OH_NO"
    after
      GenServer.call(NewRelic.Logger, {:replace, previous_logger})
    end
  end

  test "file Logger" do
    previous_logger = GenServer.call(NewRelic.Logger, {:logger, {:file, "tmp/test.log"}})

    try do
      NewRelic.log(:error, "OH_NO!")

      :timer.sleep(100)
      log = File.read!("tmp/test.log")
      assert log =~ "[ERROR]"
      assert log =~ "OH_NO"
    after
      File.rm!("tmp/test.log")
      GenServer.call(NewRelic.Logger, {:replace, previous_logger})
    end
  end

  defmodule EvilCollectorPlug do
    import Plug.Conn

    def init(options), do: options

    def call(conn, test_pid: test_pid) do
      send(test_pid, :attempt)
      send_resp(conn, 418, "teapot!")
    end
  end

  test "Log out collector error response" do
    previous_logger = GenServer.call(NewRelic.Logger, {:logger, :memory})

    {:ok, _} = Plug.Adapters.Cowboy2.http(EvilCollectorPlug, [test_pid: self()], port: 8882)

    TestHelper.with_temp_env(
      %{collector_instance_host: "localhost", port: 8882, scheme: "http"},
      fn ->
        NewRelic.Harvest.Collector.Protocol.preconnect()

        log = GenServer.call(NewRelic.Logger, :flush)
        assert log =~ "[ERROR]"
        assert log =~ "(418)"
        assert log =~ "teapot"
      end
    )

    GenServer.call(NewRelic.Logger, {:replace, previous_logger})
  end
end
