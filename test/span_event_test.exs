defmodule SpanEventTest do
  use ExUnit.Case
  use Plug.Test

  alias NewRelic.DistributedTrace
  alias NewRelic.Harvest.Collector

  @dt_header "newrelic"

  @moduletag skip: true

  setup do
    GenServer.call(Collector.AgentRun, :connected)
    :ok
  end

  test "post a span event" do
    agent_run_id = Collector.AgentRun.agent_run_id()

    s1 = %NewRelic.Span.Event{
      trace_id: "abc123"
    }

    sampling = %{
      reservoir_size: 100,
      events_seen: 1
    }

    span_events = NewRelic.Span.Event.format_spans([s1])

    payload = [agent_run_id, sampling, span_events]
    Collector.Protocol.span_event(payload)
  end

  test "collect and store some events" do
    {:ok, harvester} = Supervisor.start_child(Collector.SpanEvent.HarvesterSupervisor, [])

    s1 = %NewRelic.Span.Event{
      trace_id: "abc123"
    }

    s2 = %NewRelic.Span.Event{
      trace_id: "def456"
    }

    GenServer.cast(harvester, {:report, s1})
    GenServer.cast(harvester, {:report, s2})

    events = GenServer.call(harvester, :gather_harvest)
    assert length(events) == 2

    # Verify that the Harvester shuts down w/o error
    Process.monitor(harvester)
    Collector.SpanEvent.Harvester.complete(harvester)
    assert_receive {:DOWN, _ref, _, ^harvester, :shutdown}, 1000
  end

  test "report a span event through the harvester" do
    TestHelper.restart_harvest_cycle(Collector.SpanEvent.HarvestCycle)

    context = %DistributedTrace.Context{sampled: true}
    mfa = {:mod, :fun, 3}

    event = %NewRelic.Span.Event{
      timestamp: System.system_time(:milliseconds),
      duration: 0.120,
      name: "SomeSpan",
      category: "generic",
      category_attributes: %{}
    }

    Collector.SpanEvent.Harvester.report_span_event(context, mfa, event)

    [[attrs, _, _]] = TestHelper.gather_harvest(Collector.SpanEvent.Harvester)

    assert attrs[:type] == "Span"
    assert attrs[:category] == "generic"

    TestHelper.pause_harvest_cycle(Collector.CustomEvent.HarvestCycle)
  end

  defmodule Traced do
    use NewRelic.Tracer
    @trace :hello
    def hello do
      Process.sleep(10)
      "world"
    end

    @trace {:foo, category: :external}
    def foo do
      Process.sleep(15)
      NewRelic.set_span(:http, url: "http://example.com", method: "GET", component: "HTTPoison")
      "bar"
    end
  end

  defmodule TestPlugApp do
    use Plug.Router
    use NewRelic.Transaction

    plug(:match)
    plug(:dispatch)

    get "/hello" do
      Task.async(fn ->
        Process.sleep(5)
        Traced.foo()
      end)
      |> Task.await()

      send_resp(conn, 200, Traced.hello())
    end
  end

  test "report span events via function tracer inside transaction inside a DT" do
    TestHelper.restart_harvest_cycle(Collector.SpanEvent.HarvestCycle)
    TestHelper.restart_harvest_cycle(Collector.TransactionEvent.HarvestCycle)

    TestHelper.request(
      TestPlugApp,
      conn(:get, "/hello") |> put_req_header(@dt_header, generate_inbound_payload())
    )

    span_events = TestHelper.gather_harvest(Collector.SpanEvent.Harvester)

    [cowboy_event, _, _] =
      Enum.find(span_events, fn [ev, _, _] -> ev[:"nr.entryPoint"] == true end)

    [function_event, _, _] =
      Enum.find(span_events, fn [ev, _, _] -> ev[:name] == "SpanEventTest.Traced.hello/0" end)

    [task_event, _, _] = Enum.find(span_events, fn [ev, _, _] -> ev[:name] =~ "Process #PID" end)

    [nested_event, _, _] =
      Enum.find(span_events, fn [ev, _, _] -> ev[:name] == "SpanEventTest.Traced.foo/0" end)

    [[_intrinsics, tx_event]] = TestHelper.gather_harvest(Collector.TransactionEvent.Harvester)

    assert tx_event[:parentId] == "7d3efb1b173fecfa"

    assert tx_event[:traceId] == "d6b4ba0c3a712ca"
    assert cowboy_event[:traceId] == "d6b4ba0c3a712ca"
    assert function_event[:traceId] == "d6b4ba0c3a712ca"
    assert task_event[:traceId] == "d6b4ba0c3a712ca"
    assert nested_event[:traceId] == "d6b4ba0c3a712ca"

    assert cowboy_event[:transactionId] == tx_event[:guid]
    assert function_event[:transactionId] == tx_event[:guid]
    assert task_event[:transactionId] == tx_event[:guid]
    assert nested_event[:transactionId] == tx_event[:guid]

    assert tx_event[:sampled] == true
    assert cowboy_event[:sampled] == true
    assert function_event[:sampled] == true
    assert task_event[:sampled] == true
    assert nested_event[:sampled] == true

    assert tx_event[:priority] == 0.987654
    assert cowboy_event[:priority] == 0.987654
    assert function_event[:priority] == 0.987654
    assert task_event[:priority] == 0.987654
    assert nested_event[:priority] == 0.987654

    assert function_event[:duration] > 0.009
    assert function_event[:duration] < 0.020

    assert cowboy_event[:parentId] == "5f474d64b9cc9b2a"
    assert function_event[:parentId] == cowboy_event[:guid]
    assert task_event[:parentId] == cowboy_event[:guid]
    assert nested_event[:parentId] == task_event[:guid]

    assert function_event[:duration] > 0
    assert task_event[:duration] > 0
    assert nested_event[:duration] > 0

    assert nested_event[:category] == "http"
    assert nested_event[:"http.url"] == "http://example.com"
    assert nested_event[:"http.method"] == "GET"
    assert nested_event[:"span.kind"] == "client"
    assert nested_event[:component] == "HTTPoison"
    assert nested_event[:args]

    # Ensure these will encode properly
    Poison.encode!(tx_event)
    Poison.encode!(span_events)

    TestHelper.pause_harvest_cycle(Collector.CustomEvent.HarvestCycle)
    TestHelper.pause_harvest_cycle(Collector.TransactionEvent.HarvestCycle)
  end

  describe "Generate span GUIDs" do
    test "for a process" do
      NewRelic.DistributedTrace.generate_guid(pid: self())
      NewRelic.DistributedTrace.generate_guid(pid: self(), mfa: {:m, :f, 1})
    end
  end

  def generate_inbound_payload() do
    """
    {
      "v": [0,1],
      "d": {
        "ty": "Browser",
        "ac": "#{Collector.AgentRun.account_id()}",
        "tk": "#{Collector.AgentRun.trusted_account_key()}",
        "ap": "2827902",
        "tx": "7d3efb1b173fecfa",
        "tr": "d6b4ba0c3a712ca",
        "id": "5f474d64b9cc9b2a",
        "ti": #{System.system_time(:milliseconds) - 100},
        "sa": true,
        "pr": 0.987654
      }
    }
    """
    |> Base.encode64()
  end
end
