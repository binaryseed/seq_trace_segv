defmodule NewRelic.Config do
  @moduledoc """
  Agent Configuration
  """

  alias NewRelic.Harvest.Collector

  def enabled?, do: (configured?() && harvest_enabled?() && true) || false

  def configured?, do: (app_name() && collector_license_key() && true) || false

  def harvest_enabled?, do: Application.get_env(:new_relic, :harvest_enabled, true)

  def harvest_cycle, do: Application.get_env(:new_relic, :harvest_cycle, 1_000)

  def harvest_cycle(Collector.Metric.HarvestCycle),
    do: Application.get_env(:new_relic, :metric_harvest_cycle, 60_000)

  def harvest_cycle(Collector.TransactionTrace.HarvestCycle),
    do: Application.get_env(:new_relic, :transaction_trace_harvest_cycle, 60_000)

  def harvest_cycle(Collector.TransactionEvent.HarvestCycle),
    do: Application.get_env(:new_relic, :transaction_event_harvest_cycle, 10_000)

  def harvest_cycle(Collector.TransactionErrorEvent.HarvestCycle),
    do: Application.get_env(:new_relic, :error_event_harvest_cycle, 60_000)

  def harvest_cycle(Collector.ErrorTrace.HarvestCycle),
    do: Application.get_env(:new_relic, :error_trace_harvest_cycle, 60_000)

  def harvest_cycle(Collector.CustomEvent.HarvestCycle),
    do: Application.get_env(:new_relic, :custom_event_harvest_cycle, 10_000)

  def harvest_cycle(Collector.SpanEvent.HarvestCycle),
    do: Application.get_env(:new_relic, :span_event_harvest_cycle, 10_000)

  def reservoir_size(Collector.TransactionEvent.Harvester),
    do: Application.get_env(:new_relic, :transaction_event_reservoir_size, 1_000)

  def reservoir_size(Collector.CustomEvent.Harvester),
    do: Application.get_env(:new_relic, :custom_event_reservoir_size, 1_000)

  def reservoir_size(Collector.SpanEvent.Harvester),
    do: Application.get_env(:new_relic, :span_event_reservoir_size, 1_000)

  def sample_cycle, do: Application.get_env(:new_relic, :sample_cycle, 15_000)

  def collector_license_key,
    do:
      System.get_env("NEWRELIC_LICENSE_KEY") || System.get_env("NEW_RELIC_LICENSE_KEY") ||
        Application.get_env(:new_relic, :license_key)

  def collector_host,
    do:
      System.get_env("NEWRELIC_HOST") || System.get_env("NEW_RELIC_HOST") ||
        Application.get_env(:new_relic, :host, "staging-collector.newrelic.com")

  def collector_scheme, do: Application.get_env(:new_relic, :scheme, "https")

  def collector_port, do: Application.get_env(:new_relic, :port, 443)

  def collector_instance_host, do: Application.get_env(:new_relic, :collector_instance_host)

  def collector_raw_method,
    do:
      Application.get_env(:new_relic, :collector_raw_method, "/agent_listener/invoke_raw_method")

  def event_type,
    do:
      System.get_env("NEWRELIC_INSIGHTS_EVENT_TYPE") ||
        Application.get_env(:new_relic, :insights_event_type) ||
        Application.get_env(:new_relic, :event_type, "ElixirAgent")

  def app_name,
    do:
      System.get_env("NEWRELIC_APP_NAME") || System.get_env("NEW_RELIC_APP_NAME") ||
        Application.get_env(:new_relic, :app_name)

  def log_file_path,
    do: System.get_env("NEWRELIC_LOG_FILE_PATH") || System.get_env("NEW_RELIC_LOG_FILE_PATH")

  def logger do
    case log_file_path() do
      nil ->
        Application.get_env(:new_relic, :logger, {:file, "tmp/new_relic.log"})

      "stdout" ->
        :stdio

      log_file_path ->
        {:file, log_file_path}
    end
  end

  def automatic_attributes do
    Application.get_env(:new_relic, :automatic_attributes, [])
    |> Enum.into(%{}, fn
      {name, {:system, env_var}} -> {name, System.get_env(env_var)}
      {name, {m, f, a}} -> {name, apply(m, f, a)}
      {name, value} -> {name, value}
    end)
  end

  @external_resource "VERSION"
  @agent_version "VERSION" |> File.read!() |> String.trim()
  def agent_version, do: @agent_version
end
