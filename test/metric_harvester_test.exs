defmodule MetricHarvesterTest do
  use ExUnit.Case
  alias NewRelic.Harvest.Collector

  test "Can post a metric" do
    # https://source.datanerd.us/agents/agent-specs/blob/master/Metric-Data-Legacy.md#json-format
    # https://source.datanerd.us/APM/rpm_site/blob/master/app/models/platform_translator.rb
    # https://source.datanerd.us/APM/rpm_site/blob/master/app/models/metric_extensions/named_metrics.rb

    ts_end = System.system_time(:seconds)
    ts_start = ts_end - 60
    agent_run_id = Collector.AgentRun.agent_run_id()

    data_array = [
      [
        %{name: "HttpDispatcher", scope: ""},
        [42, 0, 0, 0, 0, 0]
      ]
      # Other metrics
    ]

    return_value = Collector.Protocol.metric_data([agent_run_id, ts_start, ts_end, data_array])
    assert return_value == []
  end

  test "harvest_cycle off during tests" do
    refute Collector.HarvestCycle.current_harvester(Collector.Metric.HarvestCycle)
    refute Collector.HarvestCycle.current_harvester(Collector.TransactionTrace.HarvestCycle)
  end

  test "Harvester - collect and aggregate some metrics" do
    {:ok, harvester} = Supervisor.start_child(Collector.Metric.HarvesterSupervisor, [])

    metric1 = %Metric{name: "TestMetric", call_count: 1, total_call_time: 100}
    metric2 = %Metric{name: "TestMetric", call_count: 1, total_call_time: 50}
    GenServer.cast(harvester, {:report, metric1})
    GenServer.cast(harvester, {:report, metric2})

    # Verify that the metric is encoded as the collector desires
    metrics = GenServer.call(harvester, :gather_harvest)
    [metric] = metrics
    [metric_ident, metric_values] = metric
    assert metric_ident == %{name: "TestMetric", scope: ""}
    assert metric_values == [2, 150, 0, 0, 0, 0]

    # Verify that the Harvester shuts down w/o error
    Process.monitor(harvester)
    Collector.Metric.Harvester.complete(harvester)
    assert_receive {:DOWN, _ref, _, ^harvester, :shutdown}, 1000

    # Check out the data!
    #   https://staging-insights.newrelic.com/accounts/190/explorer/metrics#entityId=3810473&entityName=ElixirAgentTest%20(SDK)&searchTerms=test&entityType=application&entityTypeName=Applications&view=METRICS_OF_ENTITY&timeWindow=30&metricAgentIds%5B%5D=3810473&metricNames%5B%5D=TestMetric&metricFacets%5B%5D=false&metricSegments%5B%5D=TestMetric&metricFuncs%5B%5D=average_response_time
  end

  test "harvest cycle" do
    Application.put_env(:new_relic, :metric_harvest_cycle, 300)
    TestHelper.restart_harvest_cycle(Collector.Metric.HarvestCycle)

    first = Collector.HarvestCycle.current_harvester(Collector.Metric.HarvestCycle)
    Process.monitor(first)

    # Wait until harvest swap
    assert_receive {:DOWN, _ref, _, ^first, :shutdown}, 1000

    second = Collector.HarvestCycle.current_harvester(Collector.Metric.HarvestCycle)
    Process.monitor(second)

    refute first == second
    assert Process.alive?(second)

    TestHelper.pause_harvest_cycle(Collector.Metric.HarvestCycle)
    Application.delete_env(:new_relic, :metric_harvest_cycle)

    # Ensure the last harvester has shut down
    assert_receive {:DOWN, _ref, _, ^second, :shutdown}, 1000
  end

  test "Ignore late reports" do
    TestHelper.restart_harvest_cycle(Collector.Metric.HarvestCycle)

    harvester =
      Collector.Metric.HarvestCycle
      |> Collector.HarvestCycle.current_harvester()

    assert :ok == GenServer.call(harvester, :send_harvest)

    GenServer.cast(harvester, {:report, :late_msg})

    assert :completed == GenServer.call(harvester, :send_harvest)

    TestHelper.pause_harvest_cycle(Collector.Metric.HarvestCycle)
  end
end
