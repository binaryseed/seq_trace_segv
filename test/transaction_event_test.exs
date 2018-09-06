defmodule TransactionEventTest do
  use ExUnit.Case
  use Plug.Test

  alias NewRelic.Harvest.Collector
  alias NewRelic.Transaction.Event

  defmodule TestPlugApp do
    use Plug.Router
    use NewRelic.Transaction

    plug(:match)
    plug(:dispatch)

    get "/" do
      Process.sleep(10)
      send_resp(conn, 200, "transactionEvent")
    end
  end

  test "post a transaction event" do
    agent_run_id = Collector.AgentRun.agent_run_id()

    tr_1 = %Event{
      web_duration: 0.010,
      database_duration: nil,
      timestamp: System.system_time(:milliseconds) / 1_000,
      name: "WebTransaction/AgentTest/Transaction/name",
      duration: 0.010,
      type: "Transaction",
      user_attributes: %{
        foo: "bar"
      }
    }

    sampling = %{
      reservoir_size: 100,
      events_seen: 1
    }

    transaction_events = Event.format_transactions([tr_1])
    payload = [agent_run_id, sampling, transaction_events]
    Collector.Protocol.transaction_event(payload)
  end

  test "collect and store some events" do
    {:ok, harvester} = Supervisor.start_child(Collector.TransactionEvent.HarvesterSupervisor, [])

    ev1 = %Event{name: "Ev1", duration: 1}
    ev2 = %Event{name: "Ev2", duration: 2}

    GenServer.cast(harvester, {:report, ev1})
    GenServer.cast(harvester, {:report, ev2})

    events = GenServer.call(harvester, :gather_harvest)

    assert length(events) == 2

    # Verify that the Harvester shuts down w/o error
    Process.monitor(harvester)
    Collector.TransactionEvent.Harvester.complete(harvester)
    assert_receive {:DOWN, _ref, _, ^harvester, :shutdown}, 1000
  end

  test "user attributes can be truncated" do
    TestHelper.restart_harvest_cycle(Collector.TransactionEvent.HarvestCycle)

    TestHelper.report_event(Collector.TransactionEvent.HarvestCycle, %Event{
      name: "Ev1",
      duration: 1,
      user_attributes: %{long_entry: String.duplicate("1", 5000)}
    })

    [[_, attrs]] = TestHelper.gather_harvest(Collector.TransactionEvent.Harvester)

    assert String.length(attrs.long_entry) == 4095

    TestHelper.pause_harvest_cycle(Collector.TransactionEvent.HarvestCycle)
  end

  test "harvest cycle" do
    Application.put_env(:new_relic, :transaction_event_harvest_cycle, 300)
    TestHelper.restart_harvest_cycle(Collector.TransactionEvent.HarvestCycle)

    first = Collector.HarvestCycle.current_harvester(Collector.TransactionEvent.HarvestCycle)
    Process.monitor(first)

    # Wait until harvest swap
    assert_receive {:DOWN, _ref, _, ^first, :shutdown}, 1000

    second = Collector.HarvestCycle.current_harvester(Collector.TransactionEvent.HarvestCycle)
    Process.monitor(second)

    refute first == second
    assert Process.alive?(second)

    TestHelper.pause_harvest_cycle(Collector.TransactionEvent.HarvestCycle)
    Application.delete_env(:new_relic, :transaction_event_harvest_cycle)

    # Ensure the last harvester has shut down
    assert_receive {:DOWN, _ref, _, ^second, :shutdown}, 1000
  end

  test "instrument & harvest" do
    TestHelper.restart_harvest_cycle(Collector.TransactionEvent.HarvestCycle)

    TestPlugApp.call(conn(:get, "/"), [])
    TestPlugApp.call(conn(:get, "/"), [])

    events = TestHelper.gather_harvest(Collector.TransactionEvent.Harvester)
    assert length(events) == 2

    TestHelper.pause_harvest_cycle(Collector.TransactionEvent.HarvestCycle)
  end

  test "Ignore late reports" do
    TestHelper.restart_harvest_cycle(Collector.TransactionEvent.HarvestCycle)

    harvester =
      Collector.TransactionEvent.HarvestCycle
      |> Collector.HarvestCycle.current_harvester()

    assert :ok == GenServer.call(harvester, :send_harvest)

    GenServer.cast(harvester, {:report, :late_msg})

    assert :completed == GenServer.call(harvester, :send_harvest)

    TestHelper.pause_harvest_cycle(Collector.TransactionEvent.HarvestCycle)
  end

  test "Respect the reservoir_size" do
    Application.put_env(:new_relic, :transaction_event_reservoir_size, 3)
    TestHelper.restart_harvest_cycle(Collector.TransactionEvent.HarvestCycle)

    Task.async(fn ->
      TestPlugApp.call(conn(:get, "/"), [])
      TestPlugApp.call(conn(:get, "/"), [])
      TestPlugApp.call(conn(:get, "/"), [])
      TestPlugApp.call(conn(:get, "/"), [])
      TestPlugApp.call(conn(:get, "/"), [])
    end)
    |> Task.await()

    events = TestHelper.gather_harvest(Collector.TransactionEvent.Harvester)
    assert length(events) == 3

    Application.delete_env(:new_relic, :transaction_event_reservoir_size)
    TestHelper.pause_harvest_cycle(Collector.TransactionEvent.HarvestCycle)
  end
end
