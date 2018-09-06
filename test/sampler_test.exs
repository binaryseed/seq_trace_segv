defmodule SamplerTest do
  use ExUnit.Case

  alias NewRelic.Harvest.Collector

  defmodule TestProcess do
    use GenServer

    def start_link, do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

    def init(:ok) do
      NewRelic.sample_process(self())
      {:ok, %{}}
    end

    def handle_call(:work, _from, state) do
      {:reply, :ok, state}
    end
  end

  test "Beam stats Sampler" do
    TestHelper.restart_harvest_cycle(Collector.CustomEvent.HarvestCycle)

    TestHelper.trigger_report(NewRelic.Sampler.Beam)
    events = TestHelper.gather_harvest(Collector.CustomEvent.Harvester)

    assert Enum.find(events, fn [_, event, _] ->
             event[:category] == :BeamStat && event[:reductions] > 0 && event[:process_count] > 0
           end)
  end

  test "Process Sampler" do
    TestHelper.restart_harvest_cycle(Collector.CustomEvent.HarvestCycle)
    TestProcess.start_link()

    TestHelper.trigger_report(NewRelic.Sampler.Process)
    events = TestHelper.gather_harvest(Collector.CustomEvent.Harvester)

    assert Enum.find(events, fn [_, event, _] ->
             event[:category] == :ProcessSample && event[:name] == "SamplerTest.TestProcess" &&
               event[:message_queue_length] == 0
           end)
  end

  test "unnamed Process Sampler" do
    TestHelper.restart_harvest_cycle(Collector.CustomEvent.HarvestCycle)

    parent = self()

    spawn(fn ->
      NewRelic.sample_process(self())
      TestHelper.trigger_report(NewRelic.Sampler.Process)
      send(parent, :continue)
    end)

    assert_receive :continue, 500

    events = TestHelper.gather_harvest(Collector.CustomEvent.Harvester)

    assert Enum.find(events, fn [_, event, _] ->
             event[:category] == :ProcessSample && event[:name] =~ "PID" &&
               event[:message_queue_length] == 0
           end)
  end

  test "Process Sampler - count work between samplings" do
    TestHelper.restart_harvest_cycle(Collector.CustomEvent.HarvestCycle)

    TestProcess.start_link()

    TestHelper.trigger_report(NewRelic.Sampler.Process)

    events = TestHelper.gather_harvest(Collector.CustomEvent.Harvester)

    assert Enum.find(events, fn [_, event, _] ->
             event[:category] == :ProcessSample && event[:name] == "SamplerTest.TestProcess" &&
               event[:reductions] < 5
           end)

    GenServer.call(TestProcess, :work)
    GenServer.call(TestProcess, :work)
    GenServer.call(TestProcess, :work)

    TestHelper.trigger_report(NewRelic.Sampler.Process)

    events = TestHelper.gather_harvest(Collector.CustomEvent.Harvester)

    assert Enum.find(events, fn [_, event, _] ->
             event[:category] == :ProcessSample && event[:name] == "SamplerTest.TestProcess" &&
               event[:reductions] > 5
           end)
  end

  describe "Sampler.ETS" do
    test "records metrics on ETS tables" do
      TestHelper.restart_harvest_cycle(Collector.CustomEvent.HarvestCycle)

      :ets.new(:test_table, [:named_table])
      for n <- 1..510, do: :ets.insert(:test_table, {n, "BAR"})

      TestHelper.trigger_report(NewRelic.Sampler.Ets)
      events = TestHelper.gather_harvest(Collector.CustomEvent.Harvester)

      assert Enum.find(events, fn [_, event, _] ->
               event[:category] == :EtsStat && event[:table_name] == ":test_table" &&
                 event[:size] == 510
             end)
    end

    test "record_sample/1 ignores non-existent tables" do
      assert NewRelic.Sampler.Ets.record_sample(:nope_not_here) == :ignore
    end
  end
end
