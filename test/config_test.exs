defmodule ConfigTest do
  use ExUnit.Case

  test "Version read from file" do
    assert NewRelic.Config.agent_version() == Mix.Project.config()[:version]
  end

  test "Logger output device" do
    inital_logger = NewRelic.Config.logger()

    System.put_env("NEW_RELIC_LOG_FILE_PATH", "stdout")
    assert :stdio == NewRelic.Config.logger()

    System.put_env("NEW_RELIC_LOG_FILE_PATH", "some_file.log")
    assert {:file, "some_file.log"} == NewRelic.Config.logger()

    System.delete_env("NEW_RELIC_LOG_FILE_PATH")
    assert inital_logger == NewRelic.Config.logger()
  end

  test "hydrate automatic attributes" do
    System.put_env("ENV_VAR_NAME", "env-var-value")

    Application.put_env(
      :new_relic,
      :automatic_attributes,
      env_var: {:system, "ENV_VAR_NAME"},
      function_call: {String, :upcase, ["fun"]},
      raw: "attribute"
    )

    assert NewRelic.Config.automatic_attributes() == %{
             env_var: "env-var-value",
             raw: "attribute",
             function_call: "FUN"
           }

    Application.put_env(:new_relic, :automatic_attributes, [])
    System.delete_env("ENV_VAR_NAME")
  end
end
