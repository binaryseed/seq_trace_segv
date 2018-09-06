defmodule NewRelic.Util do
  @moduledoc """
  General helper functions
  """

  def hostname do
    with {:ok, name} <- :inet.gethostname(), do: to_string(name)
  end

  def pid, do: System.get_pid() |> String.to_integer()

  def post(url, body, headers) when is_binary(body) do
    with url = to_charlist(url),
         headers = for({k, v} <- headers, do: {to_charlist(k), to_charlist(v)}) do
      :httpc.request(
        :post,
        {url, headers, 'application/json', body},
        [ssl: [verify: :verify_none]],
        []
      )
    end
  end

  def post(url, body, headers), do: post(url, Poison.encode!(body), headers)

  def time_to_ms({megasec, sec, microsec}),
    do: (megasec * 1_000_000 + sec) * 1_000 + round(microsec / 1_000)
end
