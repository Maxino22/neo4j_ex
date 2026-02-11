defmodule Neo4j.Protocol.PackStream do
  @moduledoc """
  PackStream v2 encoder and decoder for Bolt protocol.

  PackStream is a binary serialization format for graph data.
  This module handles encoding Elixir terms to PackStream format
  and decoding PackStream bytes back to Elixir terms.
  """

  import Bitwise

  # Marker bytes for different types
  @tiny_string_marker 0x80
  @tiny_list_marker 0x90
  @tiny_map_marker 0xA0
  @tiny_struct_marker 0xB0

  @null_marker 0xC0
  @false_marker 0xC2
  @true_marker 0xC3

  @int8_marker 0xC8
  @int16_marker 0xC9
  @int32_marker 0xCA
  @int64_marker 0xCB

  @float_marker 0xC1

  # Reserved for future binary data support
  # @bytes8_marker 0xCC
  # @bytes16_marker 0xCD
  # @bytes32_marker 0xCE

  @string8_marker 0xD0
  @string16_marker 0xD1
  @string32_marker 0xD2

  @list8_marker 0xD4
  @list16_marker 0xD5
  @list32_marker 0xD6

  @map8_marker 0xD8
  @map16_marker 0xD9
  @map32_marker 0xDA

  @struct8_marker 0xDC
  @struct16_marker 0xDD

  # ============================================================================
  # Encoding
  # ============================================================================

  @doc """
  Encodes an Elixir term to PackStream binary format.
  """
  def encode(nil), do: <<@null_marker>>
  def encode(false), do: <<@false_marker>>
  def encode(true), do: <<@true_marker>>

  def encode(value) when is_integer(value), do: encode_integer(value)
  def encode(value) when is_float(value), do: encode_float(value)
  def encode(value) when is_binary(value), do: encode_string(value)
  def encode(value) when is_list(value), do: encode_list(value)
  def encode({:struct, signature, fields}), do: encode_struct(signature, fields)

  # Advanced Neo4j types - must come before generic map handling
  def encode(%Neo4j.Types.Point2D{} = point) do
    fields = Neo4j.Types.encode_point(point)
    encode_struct(0x58, fields)
  end

  def encode(%Neo4j.Types.Point3D{} = point) do
    fields = Neo4j.Types.encode_point(point)
    encode_struct(0x59, fields)
  end

  def encode(%Neo4j.Types.Neo4jDate{} = date) do
    fields = Neo4j.Types.encode_date(date)
    encode_struct(0x44, fields)
  end

  def encode(%Neo4j.Types.Neo4jTime{} = time) do
    fields = Neo4j.Types.encode_time(time)
    encode_struct(0x54, fields)
  end

  def encode(%Neo4j.Types.Neo4jLocalTime{} = local_time) do
    fields = Neo4j.Types.encode_local_time(local_time)
    encode_struct(0x74, fields)
  end

  def encode(%Neo4j.Types.Neo4jDateTime{} = datetime) do
    fields = Neo4j.Types.encode_datetime(datetime)
    encode_struct(0x46, fields)
  end

  def encode(%Neo4j.Types.Neo4jLocalDateTime{} = local_datetime) do
    fields = Neo4j.Types.encode_local_datetime(local_datetime)
    encode_struct(0x64, fields)
  end

  def encode(%Neo4j.Types.Neo4jDuration{} = duration) do
    fields = Neo4j.Types.encode_duration(duration)
    encode_struct(0x45, fields)
  end

  # Elixir standard types - convert to Neo4j types
  def encode(%DateTime{} = datetime) do
    neo4j_datetime = Neo4j.Types.from_elixir_datetime(datetime)
    encode(neo4j_datetime)
  end

  def encode(%Date{} = date) do
    neo4j_date = Neo4j.Types.from_elixir_date(date)
    encode(neo4j_date)
  end

  # Generic map handling - must come after struct handling
  def encode(value) when is_map(value), do: encode_map(value)

  def encode(value) do
    raise ArgumentError, "Cannot encode value: #{inspect(value)}"
  end

  # Integer encoding
  defp encode_integer(n) when n >= -16 and n <= 127, do: <<n::signed-8>>
  defp encode_integer(n) when n >= -128 and n <= 127, do: <<@int8_marker, n::signed-8>>
  defp encode_integer(n) when n >= -32768 and n <= 32767, do: <<@int16_marker, n::signed-16>>
  defp encode_integer(n) when n >= -2147483648 and n <= 2147483647, do: <<@int32_marker, n::signed-32>>
  defp encode_integer(n), do: <<@int64_marker, n::signed-64>>

  # Float encoding
  defp encode_float(f), do: <<@float_marker, f::float-64>>

  # String encoding
  defp encode_string(s) when is_binary(s) do
    size = byte_size(s)

    cond do
      size <= 15 ->
        <<@tiny_string_marker ||| size, s::binary>>

      size <= 255 ->
        <<@string8_marker, size::8, s::binary>>

      size <= 65535 ->
        <<@string16_marker, size::16, s::binary>>

      size <= 4294967295 ->
        <<@string32_marker, size::32, s::binary>>

      true ->
        raise ArgumentError, "String too large: #{size} bytes"
    end
  end

  # List encoding
  defp encode_list(list) when is_list(list) do
    size = length(list)
    encoded_items = list |> Enum.map(&encode/1) |> IO.iodata_to_binary()

    cond do
      size <= 15 ->
        <<@tiny_list_marker ||| size, encoded_items::binary>>

      size <= 255 ->
        <<@list8_marker, size::8, encoded_items::binary>>

      size <= 65535 ->
        <<@list16_marker, size::16, encoded_items::binary>>

      size <= 4294967295 ->
        <<@list32_marker, size::32, encoded_items::binary>>

      true ->
        raise ArgumentError, "List too large: #{size} items"
    end
  end

  # Map encoding
  defp encode_map(map) when is_map(map) do
    size = map_size(map)

    encoded_pairs =
      map
      |> Enum.flat_map(fn {k, v} -> [encode(to_string(k)), encode(v)] end)
      |> IO.iodata_to_binary()

    cond do
      size <= 15 ->
        <<@tiny_map_marker ||| size, encoded_pairs::binary>>

      size <= 255 ->
        <<@map8_marker, size::8, encoded_pairs::binary>>

      size <= 65535 ->
        <<@map16_marker, size::16, encoded_pairs::binary>>

      size <= 4294967295 ->
        <<@map32_marker, size::32, encoded_pairs::binary>>

      true ->
        raise ArgumentError, "Map too large: #{size} pairs"
    end
  end

  # Structure encoding (for Bolt messages)
  defp encode_struct(signature, fields) when is_integer(signature) and is_list(fields) do
    size = length(fields)
    encoded_fields = fields |> Enum.map(&encode/1) |> IO.iodata_to_binary()

    cond do
      size <= 15 ->
        <<@tiny_struct_marker ||| size, signature::8, encoded_fields::binary>>

      size <= 255 ->
        <<@struct8_marker, size::8, signature::8, encoded_fields::binary>>

      size <= 65535 ->
        <<@struct16_marker, size::16, signature::8, encoded_fields::binary>>

      true ->
        raise ArgumentError, "Structure too large: #{size} fields"
    end
  end

  # ============================================================================
  # Decoding
  # ============================================================================

  @doc """
  Decodes PackStream binary data to Elixir terms.
  Returns {:ok, value, rest} or {:error, reason}.
  """
  def decode(<<@null_marker, rest::binary>>), do: {:ok, nil, rest}
  def decode(<<@false_marker, rest::binary>>), do: {:ok, false, rest}
  def decode(<<@true_marker, rest::binary>>), do: {:ok, true, rest}

  # Tiny int (single byte)
  def decode(<<n::signed-8, rest::binary>>) when n >= -16 and n <= 127 do
    {:ok, n, rest}
  end

  # Integers
  def decode(<<@int8_marker, n::signed-8, rest::binary>>), do: {:ok, n, rest}
  def decode(<<@int16_marker, n::signed-16, rest::binary>>), do: {:ok, n, rest}
  def decode(<<@int32_marker, n::signed-32, rest::binary>>), do: {:ok, n, rest}
  def decode(<<@int64_marker, n::signed-64, rest::binary>>), do: {:ok, n, rest}

  # Float
  def decode(<<@float_marker, f::float-64, rest::binary>>), do: {:ok, f, rest}

  # Strings
  def decode(<<marker, rest::binary>>) when (marker &&& 0xF0) == @tiny_string_marker do
    size = marker &&& 0x0F
    decode_string(size, rest)
  end

  def decode(<<@string8_marker, size::8, rest::binary>>), do: decode_string(size, rest)
  def decode(<<@string16_marker, size::16, rest::binary>>), do: decode_string(size, rest)
  def decode(<<@string32_marker, size::32, rest::binary>>), do: decode_string(size, rest)

  # Lists
  def decode(<<marker, rest::binary>>) when (marker &&& 0xF0) == @tiny_list_marker do
    size = marker &&& 0x0F
    decode_list(size, rest)
  end

  def decode(<<@list8_marker, size::8, rest::binary>>), do: decode_list(size, rest)
  def decode(<<@list16_marker, size::16, rest::binary>>), do: decode_list(size, rest)
  def decode(<<@list32_marker, size::32, rest::binary>>), do: decode_list(size, rest)

  # Maps
  def decode(<<marker, rest::binary>>) when (marker &&& 0xF0) == @tiny_map_marker do
    size = marker &&& 0x0F
    decode_map(size, rest)
  end

  def decode(<<@map8_marker, size::8, rest::binary>>), do: decode_map(size, rest)
  def decode(<<@map16_marker, size::16, rest::binary>>), do: decode_map(size, rest)
  def decode(<<@map32_marker, size::32, rest::binary>>), do: decode_map(size, rest)

  # Structures
  def decode(<<marker, signature::8, rest::binary>>) when (marker &&& 0xF0) == @tiny_struct_marker do
    size = marker &&& 0x0F
    decode_struct(signature, size, rest)
  end

  def decode(<<@struct8_marker, size::8, signature::8, rest::binary>>) do
    decode_struct(signature, size, rest)
  end

  def decode(<<@struct16_marker, size::16, signature::8, rest::binary>>) do
    decode_struct(signature, size, rest)
  end

  def decode(<<>>), do: {:error, :incomplete}
  def decode(_), do: {:error, :invalid_format}

  # Helper functions for decoding

  defp decode_string(size, data) do
    case data do
      <<string::binary-size(size), rest::binary>> ->
        {:ok, string, rest}
      _ ->
        {:error, :incomplete}
    end
  end

  defp decode_list(0, rest), do: {:ok, [], rest}
  defp decode_list(size, data) do
    decode_list_items(size, data, [])
  end

  defp decode_list_items(0, rest, acc) do
    {:ok, Enum.reverse(acc), rest}
  end

  defp decode_list_items(n, data, acc) do
    case decode(data) do
      {:ok, value, rest} ->
        decode_list_items(n - 1, rest, [value | acc])
      error ->
        error
    end
  end

  defp decode_map(0, rest), do: {:ok, %{}, rest}
  defp decode_map(size, data) do
    decode_map_pairs(size, data, %{})
  end

  defp decode_map_pairs(0, rest, acc) do
    {:ok, acc, rest}
  end

  defp decode_map_pairs(n, data, acc) do
    with {:ok, key, rest1} <- decode(data),
         {:ok, value, rest2} <- decode(rest1) do
      decode_map_pairs(n - 1, rest2, Map.put(acc, key, value))
    end
  end

  defp decode_struct(signature, size, data) do
    case decode_list_items(size, data, []) do
      {:ok, fields, rest} ->
        struct_value = convert_neo4j_struct(signature, fields)
        {:ok, struct_value, rest}
      error ->
        error
    end
  end

  # Convert Neo4j struct signatures to proper Elixir types
  defp convert_neo4j_struct(0x4E, [id, labels, properties]) do
    # Node structure (signature 0x4E = 78)
    Neo4j.Types.Node.new(id, labels, properties)
  end

  defp convert_neo4j_struct(0x4E, [id, labels, properties, element_id]) do
    # Node structure with element_id (Neo4j 5.0+)
    Neo4j.Types.Node.new(id, labels, properties, element_id)
  end

  defp convert_neo4j_struct(0x52, [id, start_id, end_id, type, properties]) do
    # Relationship structure (signature 0x52 = 82)
    Neo4j.Types.Relationship.new(id, start_id, end_id, type, properties)
  end

  defp convert_neo4j_struct(0x52, [id, start_id, end_id, type, properties, element_id]) do
    # Relationship structure with element_id (Neo4j 5.0+)
    Neo4j.Types.Relationship.new(id, start_id, end_id, type, properties, element_id)
  end

  defp convert_neo4j_struct(0x50, [nodes, relationships, indices]) do
    # Path structure (signature 0x50 = 80)
    Neo4j.Types.Path.new(nodes, relationships, indices)
  end

  # Advanced data types
  defp convert_neo4j_struct(0x58, fields) do
    # Point2D structure (signature 0x58 = 88)
    Neo4j.Types.decode_point(fields)
  end

  defp convert_neo4j_struct(0x59, fields) do
    # Point3D structure (signature 0x59 = 89)
    Neo4j.Types.decode_point(fields)
  end

  defp convert_neo4j_struct(0x44, fields) do
    # Date structure (signature 0x44 = 68)
    Neo4j.Types.decode_date(fields)
  end

  defp convert_neo4j_struct(0x54, fields) do
    # Time structure (signature 0x54 = 84)
    Neo4j.Types.decode_time(fields)
  end

  defp convert_neo4j_struct(0x74, fields) do
    # LocalTime structure (signature 0x74 = 116)
    Neo4j.Types.decode_local_time(fields)
  end

  defp convert_neo4j_struct(0x46, fields) do
    # DateTime structure with named timezone (signature 0x46 = 70)
    Neo4j.Types.decode_datetime(fields)
  end

  defp convert_neo4j_struct(0x49, fields) do
    # DateTime structure with timezone offset (signature 0x49 = 73)
    Neo4j.Types.decode_datetime(fields)
  end

  defp convert_neo4j_struct(0x69, fields) do
    # DateTime structure with named timezone - alternative signature (signature 0x69 = 105)
    Neo4j.Types.decode_datetime(fields)
  end

  defp convert_neo4j_struct(0x64, fields) do
    # LocalDateTime structure (signature 0x64 = 100)
    Neo4j.Types.decode_local_datetime(fields)
  end

  defp convert_neo4j_struct(0x45, fields) do
    # Duration structure (signature 0x45 = 69)
    Neo4j.Types.decode_duration(fields)
  end

  defp convert_neo4j_struct(signature, fields) do
    # Unknown structure - return as-is
    {:struct, signature, fields}
  end

  @doc """
  Decodes all values from binary data.
  """
  def decode_all(data, acc \\ [])

  def decode_all(<<>>, acc), do: {:ok, Enum.reverse(acc)}

  def decode_all(data, acc) do
    case decode(data) do
      {:ok, value, rest} ->
        decode_all(rest, [value | acc])
      {:error, reason} ->
        {:error, reason}
    end
  end
end
