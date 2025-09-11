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
end
