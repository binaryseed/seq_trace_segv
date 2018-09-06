defmodule NewRelic do
  @moduledoc """
  Public API functions
  """

  defdelegate set_transaction_name(name), to: NewRelic.Transaction.Reporter

  defdelegate add_attributes(attrs), to: NewRelic.Transaction.Reporter

  defdelegate incr_attributes(attrs), to: NewRelic.Transaction.Reporter

  defdelegate set_span(type, attrs), to: NewRelic.DistributedTrace

  def handle_errors(conn, error) do
    NewRelic.DistributedTrace.Tracker.cleanup(self())
    NewRelic.Transaction.Plug.add_stop_attrs(conn)
    NewRelic.Transaction.Reporter.stop(error)
  end

  defdelegate create_distributed_trace_payload(type), to: NewRelic.DistributedTrace

  defdelegate sample_process, to: NewRelic.Sampler.Process
  defdelegate sample_process(pid), to: NewRelic.Sampler.Process

  defdelegate aggregate(meta, values), to: NewRelic.Aggregate.Reporter

  def record(event, category) when is_map(event), do: record(category, event)

  def record(category, event) do
    type = NewRelic.Config.event_type()
    event = Map.put(event, :category, category)
    report_custom_event(type, event)
  end

  defdelegate report_custom_event(type, attributes),
    to: NewRelic.Harvest.Collector.CustomEvent.Harvester

  defdelegate report_span(span), to: NewRelic.Harvest.Collector.SpanEvent.Harvester

  defdelegate report_metric(identifier, values), to: NewRelic.Harvest.Collector.Metric.Harvester

  defdelegate log(level, message), to: NewRelic.Logger

  def manual_shutdown do
    if NewRelic.Config.enabled?() do
      [
        NewRelic.Harvest.Collector.Metric.HarvestCycle,
        NewRelic.Harvest.Collector.TransactionTrace.HarvestCycle,
        NewRelic.Harvest.Collector.TransactionEvent.HarvestCycle,
        NewRelic.Harvest.Collector.SpanEvent.HarvestCycle,
        NewRelic.Harvest.Collector.TransactionErrorEvent.HarvestCycle,
        NewRelic.Harvest.Collector.CustomEvent.HarvestCycle,
        NewRelic.Harvest.Collector.ErrorTrace.HarvestCycle
      ]
      |> Enum.map(&NewRelic.Harvest.Collector.HarvestCycle.manual_shutdown/1)
    end
  end
end
