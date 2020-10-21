defmodule ObsToMdTest do
  use ExUnit.Case
  doctest ObsToMd

  test "greets the world" do
    assert ObsToMd.convert("""
           [[A link]]
           """) == """
           [A link]("./A link.md")
           """
  end
end
