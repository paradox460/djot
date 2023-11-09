defmodule DjotTest do
  use ExUnit.Case
  doctest Djot

  test "greets the world" do
    assert Djot.hello() == :world
  end
end
