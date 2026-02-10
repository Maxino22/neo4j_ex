defmodule HandshakeTest do
  use ExUnit.Case
  doctest Neo4j.Connection.Handshake

  alias Neo4j.Connection.Handshake

  describe "handshake data building" do
    test "builds correct handshake packet" do
      handshake_data = Handshake.build_handshake_data()

      assert byte_size(handshake_data) == 20

      # Check magic bytes
      <<magic::binary-size(4), versions::binary-size(16)>> = handshake_data
      assert magic == <<0x60, 0x60, 0xB0, 0x17>>

      # Check version proposals
      <<v1::binary-size(4), v2::binary-size(4), v3::binary-size(4), v4::binary-size(4)>> = versions

      # Should propose Bolt versions in descending order
      assert v1 == <<4, 0, 0, 5>>  # Bolt v5.4
      assert v2 == <<3, 0, 0, 5>>  # Bolt v5.3
      assert v3 == <<2, 0, 0, 5>>  # Bolt v5.2
      assert v4 == <<1, 0, 0, 5>>  # Bolt v5.1
    end
  end

  describe "version parsing" do
    test "parses Neo4j version format correctly" do
      # Neo4j format: <<minor, 0, 0, major>>
      assert {:ok, {5, 4}} = Handshake.parse_version(<<4, 0, 0, 5>>)
      assert {:ok, {5, 3}} = Handshake.parse_version(<<3, 0, 0, 5>>)
      assert {:ok, {5, 2}} = Handshake.parse_version(<<2, 0, 0, 5>>)
      assert {:ok, {5, 1}} = Handshake.parse_version(<<1, 0, 0, 5>>)
    end

    test "parses Memgraph/alternative version format correctly" do
      # Memgraph format: <<0, 0, minor, major>>
      assert {:ok, {5, 4}} = Handshake.parse_version(<<0, 0, 4, 5>>)
      assert {:ok, {5, 3}} = Handshake.parse_version(<<0, 0, 3, 5>>)
      assert {:ok, {5, 2}} = Handshake.parse_version(<<0, 0, 2, 5>>)
      assert {:ok, {5, 1}} = Handshake.parse_version(<<0, 0, 1, 5>>)
    end

    test "returns error for invalid version format" do
      # Invalid formats that don't match either Neo4j or Memgraph patterns
      assert {:error, :invalid_version_format} = Handshake.parse_version(<<1, 2, 3, 4>>)
      assert {:error, :invalid_version_format} = Handshake.parse_version(<<5, 0, 1, 0>>)
      assert {:error, :invalid_version_format} = Handshake.parse_version(<<0, 1, 2, 3>>)
    end
  end
end
