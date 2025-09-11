defmodule Neo4jExTest do
  use ExUnit.Case
  doctest Neo4jEx

  test "returns version" do
    version = Neo4jEx.version()
    assert is_binary(version)
    assert version != ""
  end
end
