use Mix.Config

config :logger, level: :warn

config :new_relic,
  harvest_enabled: false,
  app_name: "ElixirAgentTest",
  event_type: "ElixirAgentTest",
  automatic_attributes: [
    test_attribute: "test_value"
  ],
  logger: :memory
