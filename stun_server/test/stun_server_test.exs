defmodule StunServerTest do
  use ExUnit.Case
  doctest StunServer

  test "greets the world" do
    assert StunServer.hello() == :world
  end
end
