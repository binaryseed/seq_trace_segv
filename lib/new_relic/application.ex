defmodule NewRelic.Application do
  use Application

  @moduledoc """
  NewRelic Agent processes
  """

  def start(_type, _args) do
    import Supervisor.Spec

    System.build_info()
    |> require_otp_version()

    children = [
      worker(NewRelic.Logger, []),
      supervisor(NewRelic.Harvest.Supervisor, []),
      supervisor(NewRelic.Sampler.Supervisor, []),
      supervisor(NewRelic.Error.Supervisor, []),
      supervisor(NewRelic.Transaction.Supervisor, []),
      supervisor(NewRelic.DistributedTrace.Supervisor, []),
      supervisor(NewRelic.Aggregate.Supervisor, [])
    ]

    opts = [strategy: :one_for_one, name: NewRelic.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def require_otp_version(%{otp_release: "21"}), do: :great
  def require_otp_version(%{otp_release: _}), do: raise("OTP 21 Required")
end
