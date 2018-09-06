defmodule NewRelic.Mixfile do
  use Mix.Project

  def project do
    [
      app: :new_relic,
      version: agent_version(),
      elixir: "~> 1.7",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger, :inets, :ssl], mod: {NewRelic.Application, []}]
  end

  defp package do
    [
      organization: "newrelic",
      description: "Stealth NewRelic Elixir Agent",
      files: ["lib", "mix.exs", "README.md", "CHANGELOG.md", "VERSION"],
      maintainers: ["Vince Foley"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://source.datanerd.us/after/elixir_agent"}
    ]
  end

  defp deps do
    [
      {:poison, ">= 2.0.0"},
      {:cowboy, "~> 2.0"},
      {:plug, ">= 1.5.0"}
    ]
  end

  @agent_version File.read!("VERSION") |> String.trim()
  def agent_version, do: @agent_version
end
