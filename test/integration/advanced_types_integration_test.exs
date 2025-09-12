defmodule Neo4jEx.AdvancedTypesIntegrationTest do
  use ExUnit.Case

  alias Neo4j.Types
  alias Neo4j.Protocol.PackStream

  @moduletag :integration

  describe "Advanced Types Integration" do
    test "Point types work end-to-end" do
      # Test Point2D
      point_2d = Types.point_2d(40.7128, -74.0060)
      assert %Types.Point2D{x: 40.7128, y: -74.0060, srid: 4326} = point_2d

      # Test Point3D
      point_3d = Types.point_3d(40.7128, -74.0060, 10.5)
      assert %Types.Point3D{x: 40.7128, y: -74.0060, z: 10.5, srid: 4979} = point_3d

      # Test encoding/decoding roundtrip
      encoded_2d = Types.encode_point(point_2d)
      decoded_2d = Types.decode_point(encoded_2d)
      assert decoded_2d == point_2d

      # Test PackStream roundtrip
      encoded_ps = PackStream.encode(point_2d)
      {:ok, decoded_ps, <<>>} = PackStream.decode(encoded_ps)
      assert decoded_ps == point_2d
    end

    test "Temporal types work end-to-end" do
      # Test Date conversion
      elixir_date = ~D[2024-01-15]
      neo4j_date = Types.from_elixir_date(elixir_date)
      assert %Types.Neo4jDate{year: 2024, month: 1, day: 15} = neo4j_date

      converted_back = Types.to_elixir_date(neo4j_date)
      assert converted_back == elixir_date

      # Test DateTime conversion
      elixir_datetime = DateTime.from_naive!(~N[2024-01-15 10:30:45.123456], "Etc/UTC")
      neo4j_datetime = Types.from_elixir_datetime(elixir_datetime)
      assert %Types.Neo4jDateTime{
        year: 2024, month: 1, day: 15,
        hour: 10, minute: 30, second: 45,
        nanosecond: 123456000,
        timezone_id: "Etc/UTC"
      } = neo4j_datetime

      # Test Duration
      duration = %Types.Neo4jDuration{months: 1, days: 15, seconds: 3600, nanoseconds: 123456789}
      encoded_duration = Types.encode_duration(duration)
      decoded_duration = Types.decode_duration(encoded_duration)
      assert decoded_duration == duration
    end

    test "PackStream integration works for all types" do
      # Test all advanced types through PackStream
      point_2d = Types.point_2d(40.7128, -74.0060)
      point_3d = Types.point_3d(40.7128, -74.0060, 10.5)
      neo4j_date = Types.from_elixir_date(~D[2024-01-15])
      neo4j_datetime = Types.from_elixir_datetime(DateTime.utc_now())
      duration = %Types.Neo4jDuration{months: 1, days: 15, seconds: 3600, nanoseconds: 123456789}
      time = %Types.Neo4jTime{hour: 10, minute: 30, second: 45, nanosecond: 123456789, timezone_offset_seconds: -18000}
      local_time = %Types.Neo4jLocalTime{hour: 10, minute: 30, second: 45, nanosecond: 123456789}
      local_datetime = %Types.Neo4jLocalDateTime{year: 2024, month: 1, day: 15, hour: 10, minute: 30, second: 45, nanosecond: 123456789}

      types_to_test = [
        point_2d, point_3d, neo4j_date, neo4j_datetime,
        duration, time, local_time, local_datetime
      ]

      for type <- types_to_test do
        encoded = PackStream.encode(type)
        {:ok, decoded, <<>>} = PackStream.decode(encoded)
        assert decoded == type, "Failed roundtrip for #{inspect(type)}"
      end
    end

    test "Elixir standard types are automatically converted" do
      # Test Elixir Date
      elixir_date = ~D[2024-01-15]
      encoded = PackStream.encode(elixir_date)
      {:ok, decoded, <<>>} = PackStream.decode(encoded)
      expected = Types.from_elixir_date(elixir_date)
      assert decoded == expected

      # Test Elixir DateTime
      elixir_datetime = DateTime.from_naive!(~N[2024-01-15 10:30:45.123456], "Etc/UTC")
      encoded = PackStream.encode(elixir_datetime)
      {:ok, decoded, <<>>} = PackStream.decode(encoded)
      expected = Types.from_elixir_datetime(elixir_datetime)
      assert decoded == expected
    end

    test "Complex data structures work correctly" do
      point_2d = Types.point_2d(40.7128, -74.0060)
      point_3d = Types.point_3d(40.7128, -74.0060, 10.5)
      neo4j_date = Types.from_elixir_date(~D[2024-01-15])
      duration = %Types.Neo4jDuration{months: 1, days: 15, seconds: 3600, nanoseconds: 123456789}

      # Test map containing advanced types
      complex_map = %{
        "location" => point_2d,
        "created" => neo4j_date,
        "duration" => duration,
        "metadata" => %{
          "points" => [point_2d, point_3d],
          "name" => "Test Location"
        }
      }

      encoded = PackStream.encode(complex_map)
      {:ok, decoded, <<>>} = PackStream.decode(encoded)
      assert decoded == complex_map

      # Test list containing advanced types
      complex_list = [point_2d, point_3d, neo4j_date, duration]
      encoded = PackStream.encode(complex_list)
      {:ok, decoded, <<>>} = PackStream.decode(encoded)
      assert decoded == complex_list
    end

    test "Type detection works correctly" do
      point_2d = Types.point_2d(40.7128, -74.0060)
      neo4j_date = Types.from_elixir_date(~D[2024-01-15])
      duration = %Types.Neo4jDuration{months: 1, days: 15, seconds: 3600, nanoseconds: 123456789}

      # Advanced types should be detected
      assert Types.advanced_type?(point_2d)
      assert Types.advanced_type?(neo4j_date)
      assert Types.advanced_type?(duration)
      assert Types.advanced_type?(DateTime.utc_now())
      assert Types.advanced_type?(Date.utc_today())

      # Non-advanced types should not be detected
      refute Types.advanced_type?("string")
      refute Types.advanced_type?(123)
      refute Types.advanced_type?([1, 2, 3])
      refute Types.advanced_type?(%{key: "value"})
    end

    test "Edge cases are handled correctly" do
      # Test epoch date
      epoch_date = %Types.Neo4jDate{year: 1970, month: 1, day: 1}
      encoded = Types.encode_date(epoch_date)
      assert encoded == [0]
      decoded = Types.decode_date(encoded)
      assert decoded == epoch_date

      # Test midnight time
      midnight = %Types.Neo4jLocalTime{hour: 0, minute: 0, second: 0, nanosecond: 0}
      encoded = Types.encode_local_time(midnight)
      assert encoded == [0]
      decoded = Types.decode_local_time(encoded)
      assert decoded == midnight

      # Test zero duration
      zero_duration = %Types.Neo4jDuration{months: 0, days: 0, seconds: 0, nanoseconds: 0}
      encoded = Types.encode_duration(zero_duration)
      assert encoded == [0, 0, 0, 0]
      decoded = Types.decode_duration(encoded)
      assert decoded == zero_duration

      # Test negative coordinates
      negative_point = %Types.Point2D{x: -180.0, y: -90.0, srid: 4326}
      encoded = Types.encode_point(negative_point)
      decoded = Types.decode_point(encoded)
      assert decoded == negative_point
    end

    test "Struct signatures are correct" do
      point_2d = Types.point_2d(1.0, 2.0)
      encoded = PackStream.encode(point_2d)

      # The encoded binary should contain the signature 0x58 (88) for Point2D
      <<_size_marker, 0x58, _rest::binary>> = encoded

      # Test manual decoding with correct signature
      fields = [4326, 1.0, 2.0]
      encoded_fields = Enum.map(fields, &PackStream.encode/1) |> IO.iodata_to_binary()
      manual_encoded = <<0xB3, 0x58, encoded_fields::binary>>

      {:ok, decoded, <<>>} = PackStream.decode(manual_encoded)
      assert %Types.Point2D{x: 1.0, y: 2.0, srid: 4326} = decoded
    end
  end
end
