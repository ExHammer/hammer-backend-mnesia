defmodule Hammer.Backend.MnesiaTest do
  use ExUnit.Case
  doctest Hammer.Backend.Mnesia

  test "greets the world" do
    assert Hammer.Backend.Mnesia.hello() == :world
  end
end
