defmodule UtilTest do
  use ExUnit.Case

  test "respects max attr size" do
    events = [%{giant: String.duplicate("A", 5_000), gianter: String.duplicate("A", 10_000)}]
    [%{giant: giant, gianter: gianter}] = NewRelic.Util.Event.process(events)
    assert String.length(giant) == 4095
    assert String.length(gianter) == 4095
  end

  test "Processes various attribute types" do
    assert %{key: "blah"} == NewRelic.Util.Event.process_event(%{key: "blah"})
    assert %{key: 1.2} == NewRelic.Util.Event.process_event(%{key: 1.2})
    assert %{key: [1, 2, 3]} == NewRelic.Util.Event.process_event(%{key: [1, 2, 3]})

    # Don't fail if a bitstring winds up there
    assert NewRelic.Util.Event.process_event(%{key: <<1::3>>})

    # Don't fail if a pid winds up in there
    assert NewRelic.Util.Event.process_event(%{key: self()})

    # Don't inspect the nodename, we don't want the atom char in the attribute
    json = NewRelic.Util.Event.process_event(%{key: Node.self()}) |> Poison.encode!()
    refute json =~ ":node"
  end

  test "Truncates unicode strings correctly" do
    %{key: truncated} =
      NewRelic.Util.Event.process_event(%{key: String.duplicate("a", 4094) <> "é"})

    assert byte_size(truncated) == 4094
  end
end
