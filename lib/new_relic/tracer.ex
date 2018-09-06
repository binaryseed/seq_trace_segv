defmodule NewRelic.Tracer do
  @moduledoc """
  Function tracer
  """

  defmacro __using__(_args) do
    quote do
      require NewRelic.Tracer.Macro
      require NewRelic.Tracer.Report
      Module.register_attribute(__MODULE__, :nr_tracers, accumulate: true)
      Module.register_attribute(__MODULE__, :nr_last_tracer, accumulate: false)
      @before_compile NewRelic.Tracer.Macro
      @on_definition NewRelic.Tracer.Macro
    end
  end
end
