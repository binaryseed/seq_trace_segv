defmodule NewRelic.Logger do
  use GenServer

  @moduledoc """
  Log Agent events to the given output device
  """

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    logger = NewRelic.Config.logger()
    {:ok, io_device} = device(logger)
    {:ok, %{io_device: io_device, logger: logger}}
  end

  # API

  @levels [:debug, :info, :warn, :error]
  def log(level, message) when level in @levels do
    GenServer.cast(__MODULE__, {:log, level, message})
  end

  # Server

  def handle_cast({:log, level, message}, %{io_device: io_device} = state) do
    IO.write(io_device, formatted(level, message))
    {:noreply, state}
  end

  def handle_call(:flush, _from, %{logger: :memory, io_device: io_device} = state) do
    {:reply, StringIO.flush(io_device), state}
  end

  def handle_call({:logger, logger}, _from, old_state) do
    {:ok, io_device} = device(logger)
    {:reply, old_state, %{io_device: io_device, logger: logger}}
  end

  def handle_call({:replace, logger}, _from, _old_state) do
    {:reply, :ok, logger}
  end

  # Helpers

  def device(:stdio), do: {:ok, :stdio}
  def device(:memory), do: StringIO.open("")

  def device({:file, logfile}) do
    log(:info, "Log File: #{Path.absname(logfile)}")
    logfile |> Path.dirname() |> File.mkdir_p!()
    {:ok, _file} = File.open(logfile, [:append, :utf8])
  end

  @sep " - "
  def formatted(level, message), do: [formatted(level), @sep, timestamp(), @sep, message, "\n"]
  def formatted(:debug), do: "[DEBUG]"
  def formatted(:info), do: "[INFO]"
  def formatted(:warn), do: "[WARN]"
  def formatted(:error), do: "[ERROR]"

  def timestamp do
    :calendar.local_time()
    |> NaiveDateTime.from_erl!()
    |> NaiveDateTime.to_string()
  end
end
