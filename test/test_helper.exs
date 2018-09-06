defmodule TestHelper do
  def request(module, conn) do
    Task.async(fn ->
      try do
        module.call(conn, [])
      rescue
        error -> error
      end
    end)
    |> Task.await()
  end

  def trigger_report(module) do
    Process.sleep(200)
    GenServer.call(module, :report)
  end

  def report_event(harvest_cycle, ev) do
    harvest_cycle
    |> NewRelic.Harvest.Collector.HarvestCycle.current_harvester()
    |> GenServer.cast({:report, ev})
  end

  def gather_harvest(harvester) do
    Process.sleep(200)
    harvester.gather_harvest
  end

  def restart_harvest_cycle(harvest_cycle) do
    GenServer.call(harvest_cycle, :restart)
  end

  def pause_harvest_cycle(harvest_cycle) do
    GenServer.call(harvest_cycle, :pause)
  end

  def with_temp_env(env, fnc) do
    original_env = env |> Enum.map(fn {key, _} -> {key, Application.get_env(:new_relic, key)} end)
    env |> Enum.each(fn {key, value} -> Application.put_env(:new_relic, key, value) end)

    fnc.()

    original_env
    |> Enum.each(fn
      {key, nil} -> Application.delete_env(:new_relic, key)
      {key, value} -> Application.put_env(:new_relic, key, value)
    end)
  end
end

ExUnit.start()

System.at_exit(fn _ ->
  IO.puts(GenServer.call(NewRelic.Logger, :flush))
end)
