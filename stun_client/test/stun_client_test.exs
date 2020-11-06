defmodule StunClientTest do
  use ExUnit.Case
  doctest StunClient

  test "greets the world" do
    assert StunClient.hello() == :world
  end
end
