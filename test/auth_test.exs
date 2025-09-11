defmodule PackStreamTest do
  use ExUnit.Case
  doctest Neo4j.Protocol.PackStream

  alias Neo4j.Protocol.PackStream

  describe "PackStream encoding and decoding" do
    test "encodes and decodes nil" do
      assert PackStream.encode(nil) == <<0xC0>>
      assert PackStream.decode(<<0xC0>>) == {:ok, nil, <<>>}
    end

    test "encodes and decodes booleans" do
      assert PackStream.encode(true) == <<0xC3>>
      assert PackStream.encode(false) == <<0xC2>>

      assert PackStream.decode(<<0xC3>>) == {:ok, true, <<>>}
      assert PackStream.decode(<<0xC2>>) == {:ok, false, <<>>}
    end

    test "encodes and decodes integers" do
      # Tiny int
      assert PackStream.encode(42) == <<42>>
      assert PackStream.decode(<<42>>) == {:ok, 42, <<>>}

      # Negative tiny int
      assert PackStream.encode(-17) == <<0xC8, 0xEF>>
      assert PackStream.decode(<<0xC8, 0xEF>>) == {:ok, -17, <<>>}
    end

    test "encodes and decodes floats" do
      encoded = PackStream.encode(3.14)
      assert <<0xC1, _::binary-size(8)>> = encoded

      {:ok, decoded, <<>>} = PackStream.decode(encoded)
      assert_in_delta decoded, 3.14, 0.001
    end

    test "encodes and decodes strings" do
      # Tiny string
      encoded = PackStream.encode("Hello")
      assert encoded == <<0x85, "Hello">>
      assert PackStream.decode(encoded) == {:ok, "Hello", <<>>}
    end

    test "encodes and decodes lists" do
      # Tiny list
      list = ["a", "b", "c"]
      encoded = PackStream.encode(list)
      assert PackStream.decode(encoded) == {:ok, list, <<>>}
    end

    test "encodes and decodes maps" do
      map = %{"key" => "value", "num" => 123}
      encoded = PackStream.encode(map)
      {:ok, decoded, <<>>} = PackStream.decode(encoded)

      # Maps may have different key order, so check contents
      assert decoded["key"] == "value"
      assert decoded["num"] == 123
      assert map_size(decoded) == 2
    end

    test "encodes and decodes structures" do
      struct = {:struct, 1, [%{"test" => "data"}]}
      encoded = PackStream.encode(struct)
      assert PackStream.decode(encoded) == {:ok, struct, <<>>}
    end

    test "round-trip encoding and decoding" do
      test_values = [
        nil,
        true,
        false,
        42,
        -17,
        3.14,
        "Hello",
        ["a", "b", "c"],
        %{"key" => "value", "num" => 123},
        {:struct, 1, [%{"test" => "data"}]}
      ]

      for value <- test_values do
        encoded = PackStream.encode(value)
        {:ok, decoded, <<>>} = PackStream.decode(encoded)

        case value do
          %{} = map ->
            # For maps, check contents rather than exact equality
            assert map_size(decoded) == map_size(map)
            for {k, v} <- map do
              assert decoded[k] == v
            end
          _ ->
            assert decoded == value
        end
      end
    end

    test "handles incomplete data" do
      assert PackStream.decode(<<>>) == {:error, :incomplete}
      assert PackStream.decode(<<0x85, "Hel">>) == {:error, :incomplete}
    end

    test "handles invalid format" do
      # 0xFF is actually a valid tiny int (-1), so let's test with a truly invalid marker
      # Use a reserved marker that's not implemented
      assert PackStream.decode(<<0xCF>>) == {:error, :invalid_format}
    end
  end
end
