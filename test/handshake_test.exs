defmodule HandshakeTest do
  use ExUnit.Case
  doctest Neo4j.Connection.Handshake

  alias Neo4j.Connection.Handshake

  describe "handshake data building" do
    test "builds correct handshake packet with exactly 4 proposals" do
      handshake_data = Handshake.build_handshake_data()

      assert byte_size(handshake_data) == 20

      # Check magic bytes
      <<magic::binary-size(4), versions::binary-size(16)>> = handshake_data
      assert magic == <<0x60, 0x60, 0xB0, 0x17>>

      # Check version proposals (modern format: <<minor, 0, 0, major>>)
      <<v1::binary-size(4), v2::binary-size(4), v3::binary-size(4), v4::binary-size(4)>> =
        versions

      # Bolt v5.4
      assert v1 == <<4, 0, 0, 5>>
      # Bolt v5.3
      assert v2 == <<3, 0, 0, 5>>
      # Bolt v4.4
      assert v3 == <<4, 0, 0, 4>>
      # Bolt v4.3
      assert v4 == <<3, 0, 0, 4>>
    end
  end

  describe "version parsing" do
    test "parses modern Neo4j format correctly (minor, 0, 0, major)" do
      assert {:ok, {5, 4}} = Handshake.parse_version(<<4, 0, 0, 5>>)
      assert {:ok, {5, 3}} = Handshake.parse_version(<<3, 0, 0, 5>>)
      assert {:ok, {4, 4}} = Handshake.parse_version(<<4, 0, 0, 4>>)
      assert {:ok, {4, 3}} = Handshake.parse_version(<<3, 0, 0, 4>>)
    end

    test "parses legacy/Memgraph format correctly (0, 0, minor, major)" do
      assert {:ok, {5, 4}} = Handshake.parse_version(<<0, 0, 4, 5>>)
      assert {:ok, {5, 3}} = Handshake.parse_version(<<0, 0, 3, 5>>)
      assert {:ok, {4, 4}} = Handshake.parse_version(<<0, 0, 4, 4>>)
      assert {:ok, {4, 3}} = Handshake.parse_version(<<0, 0, 3, 4>>)
    end

    test "parses alternative formats correctly" do
      # (major, minor, 0, 0)
      assert {:ok, {5, 4}} = Handshake.parse_version(<<5, 4, 0, 0>>)
      # (0, major, 0, minor)
      assert {:ok, {5, 4}} = Handshake.parse_version(<<0, 5, 0, 4>>)
    end

    test "returns error for completely invalid version formats" do
      assert {:error, :invalid_version_format} = Handshake.parse_version(<<1, 2, 3, 4>>)
      assert {:error, :invalid_version_format} = Handshake.parse_version(<<255, 255, 255, 255>>)
    end
  end

  describe "supported_version?" do
    test "returns true for supported versions" do
      assert Handshake.supported_version?({5, 4})
      assert Handshake.supported_version?({5, 3})
      assert Handshake.supported_version?({4, 4})
      assert Handshake.supported_version?({4, 3})
    end

    test "returns false for unsupported versions" do
      refute Handshake.supported_version?({5, 0})
      refute Handshake.supported_version?({4, 2})
      refute Handshake.supported_version?({3, 0})
    end
  end

  describe "supported_versions/0" do
    test "returns the list of supported versions" do
      assert Handshake.supported_versions() == [{5, 4}, {5, 3}, {4, 4}, {4, 3}]
    end
  end
end
