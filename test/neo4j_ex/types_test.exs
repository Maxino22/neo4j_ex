defmodule Neo4jEx.TypesTest do
  use ExUnit.Case
  doctest Neo4j.Types

  alias Neo4j.Types
  alias Neo4j.Protocol.PackStream

  describe "Point2D" do
    test "creates 2D point with default WGS84 SRID" do
      point = Types.point_2d(40.7128, -74.0060)
      assert %Types.Point2D{x: 40.7128, y: -74.0060, srid: 4326} = point
    end

    test "creates 2D point with custom SRID" do
      point = Types.point_2d(100.0, 200.0, 7203)
      assert %Types.Point2D{x: 100.0, y: 200.0, srid: 7203} = point
    end

    test "encodes and decodes 2D point correctly" do
      original = %Types.Point2D{x: 40.7128, y: -74.0060, srid: 4326}
      encoded = Types.encode_point(original)
      decoded = Types.decode_point(encoded)
      assert decoded == original
    end

    test "PackStream roundtrip for 2D point" do
      original = %Types.Point2D{x: 40.7128, y: -74.0060, srid: 4326}
      encoded = PackStream.encode(original)
      {:ok, decoded, <<>>} = PackStream.decode(encoded)
      assert decoded == original
    end
  end

  describe "Point3D" do
    test "creates 3D point with default WGS84 SRID" do
      point = Types.point_3d(40.7128, -74.0060, 10.5)
      assert %Types.Point3D{x: 40.7128, y: -74.0060, z: 10.5, srid: 4979} = point
    end

    test "creates 3D point with custom SRID" do
      point = Types.point_3d(100.0, 200.0, 50.0, 9157)
      assert %Types.Point3D{x: 100.0, y: 200.0, z: 50.0, srid: 9157} = point
    end

    test "encodes and decodes 3D point correctly" do
      original = %Types.Point3D{x: 40.7128, y: -74.0060, z: 10.5, srid: 4979}
      encoded = Types.encode_point(original)
      decoded = Types.decode_point(encoded)
      assert decoded == original
    end

    test "PackStream roundtrip for 3D point" do
      original = %Types.Point3D{x: 40.7128, y: -74.0060, z: 10.5, srid: 4979}
      encoded = PackStream.encode(original)
      {:ok, decoded, <<>>} = PackStream.decode(encoded)
      assert decoded == original
    end
  end

  describe "Neo4jDate" do
    test "converts from Elixir Date" do
      elixir_date = ~D[2024-01-15]
      neo4j_date = Types.from_elixir_date(elixir_date)
      assert %Types.Neo4jDate{year: 2024, month: 1, day: 15} = neo4j_date
    end

    test "converts to Elixir Date" do
      neo4j_date = %Types.Neo4jDate{year: 2024, month: 1, day: 15}
      elixir_date = Types.to_elixir_date(neo4j_date)
      assert elixir_date == ~D[2024-01-15]
    end

    test "encodes and decodes date correctly" do
      original = %Types.Neo4jDate{year: 2024, month: 1, day: 15}
      encoded = Types.encode_date(original)
      decoded = Types.decode_date(encoded)
      assert decoded == original
    end

    test "PackStream roundtrip for Neo4jDate" do
      original = %Types.Neo4jDate{year: 2024, month: 1, day: 15}
      encoded = PackStream.encode(original)
      {:ok, decoded, <<>>} = PackStream.decode(encoded)
      assert decoded == original
    end

    test "PackStream roundtrip for Elixir Date" do
      original = ~D[2024-01-15]
      encoded = PackStream.encode(original)
      {:ok, decoded, <<>>} = PackStream.decode(encoded)
      expected = Types.from_elixir_date(original)
      assert decoded == expected
    end
  end

  describe "Neo4jTime" do
    test "encodes and decodes time correctly" do
      original = %Types.Neo4jTime{
        hour: 10, minute: 30, second: 45, nanosecond: 123456789,
        timezone_offset_seconds: -18000
      }
      encoded = Types.encode_time(original)
      decoded = Types.decode_time(encoded)
      assert decoded == original
    end

    test "PackStream roundtrip for Neo4jTime" do
      original = %Types.Neo4jTime{
        hour: 10, minute: 30, second: 45, nanosecond: 123456789,
        timezone_offset_seconds: -18000
      }
      encoded = PackStream.encode(original)
      {:ok, decoded, <<>>} = PackStream.decode(encoded)
      assert decoded == original
    end
  end

  describe "Neo4jLocalTime" do
    test "encodes and decodes local time correctly" do
      original = %Types.Neo4jLocalTime{
        hour: 10, minute: 30, second: 45, nanosecond: 123456789
      }
      encoded = Types.encode_local_time(original)
      decoded = Types.decode_local_time(encoded)
      assert decoded == original
    end

    test "PackStream roundtrip for Neo4jLocalTime" do
      original = %Types.Neo4jLocalTime{
        hour: 10, minute: 30, second: 45, nanosecond: 123456789
      }
      encoded = PackStream.encode(original)
      {:ok, decoded, <<>>} = PackStream.decode(encoded)
      assert decoded == original
    end
  end

  describe "Neo4jDateTime" do
    test "converts from Elixir DateTime" do
      elixir_datetime = DateTime.from_naive!(~N[2024-01-15 10:30:45.123456], "Etc/UTC")
      neo4j_datetime = Types.from_elixir_datetime(elixir_datetime)

      assert %Types.Neo4jDateTime{
        year: 2024, month: 1, day: 15,
        hour: 10, minute: 30, second: 45,
        nanosecond: 123456000,
        timezone_id: "Etc/UTC"
      } = neo4j_datetime
    end

    test "converts to Elixir DateTime" do
      neo4j_datetime = %Types.Neo4jDateTime{
        year: 2024, month: 1, day: 15,
        hour: 10, minute: 30, second: 45,
        nanosecond: 123456000,
        timezone_id: "Etc/UTC"
      }
      elixir_datetime = Types.to_elixir_datetime(neo4j_datetime)

      expected = DateTime.from_naive!(~N[2024-01-15 10:30:45.123456], "Etc/UTC")
      assert elixir_datetime == expected
    end

    test "encodes and decodes datetime correctly" do
      original = %Types.Neo4jDateTime{
        year: 2024, month: 1, day: 15,
        hour: 10, minute: 30, second: 45,
        nanosecond: 123456789,
        timezone_id: "Etc/UTC"
      }
      encoded = Types.encode_datetime(original)
      decoded = Types.decode_datetime(encoded)
      assert decoded == original
    end

    test "PackStream roundtrip for Neo4jDateTime" do
      original = %Types.Neo4jDateTime{
        year: 2024, month: 1, day: 15,
        hour: 10, minute: 30, second: 45,
        nanosecond: 123456789,
        timezone_id: "Etc/UTC"
      }
      encoded = PackStream.encode(original)
      {:ok, decoded, <<>>} = PackStream.decode(encoded)
      assert decoded == original
    end

    test "PackStream roundtrip for Elixir DateTime" do
      original = DateTime.from_naive!(~N[2024-01-15 10:30:45.123456], "Etc/UTC")
      encoded = PackStream.encode(original)
      {:ok, decoded, <<>>} = PackStream.decode(encoded)
      expected = Types.from_elixir_datetime(original)
      assert decoded == expected
    end
  end

  describe "Neo4jLocalDateTime" do
    test "encodes and decodes local datetime correctly" do
      original = %Types.Neo4jLocalDateTime{
        year: 2024, month: 1, day: 15,
        hour: 10, minute: 30, second: 45,
        nanosecond: 123456789
      }
      encoded = Types.encode_local_datetime(original)
      decoded = Types.decode_local_datetime(encoded)
      assert decoded == original
    end

    test "PackStream roundtrip for Neo4jLocalDateTime" do
      original = %Types.Neo4jLocalDateTime{
        year: 2024, month: 1, day: 15,
        hour: 10, minute: 30, second: 45,
        nanosecond: 123456789
      }
      encoded = PackStream.encode(original)
      {:ok, decoded, <<>>} = PackStream.decode(encoded)
      assert decoded == original
    end
  end

  describe "Neo4jDuration" do
    test "encodes and decodes duration correctly" do
      original = %Types.Neo4jDuration{
        months: 12, days: 30, seconds: 3600, nanoseconds: 123456789
      }
      encoded = Types.encode_duration(original)
      decoded = Types.decode_duration(encoded)
      assert decoded == original
    end

    test "PackStream roundtrip for Neo4jDuration" do
      original = %Types.Neo4jDuration{
        months: 12, days: 30, seconds: 3600, nanoseconds: 123456789
      }
      encoded = PackStream.encode(original)
      {:ok, decoded, <<>>} = PackStream.decode(encoded)
      assert decoded == original
    end
  end

  describe "advanced_type? helper" do
    test "identifies advanced types correctly" do
      assert Types.advanced_type?(%Types.Point2D{x: 1, y: 2, srid: 4326})
      assert Types.advanced_type?(%Types.Point3D{x: 1, y: 2, z: 3, srid: 4979})
      assert Types.advanced_type?(%Types.Neo4jDate{year: 2024, month: 1, day: 15})
      assert Types.advanced_type?(%Types.Neo4jTime{hour: 10, minute: 30, second: 45, nanosecond: 0, timezone_offset_seconds: 0})
      assert Types.advanced_type?(%Types.Neo4jLocalTime{hour: 10, minute: 30, second: 45, nanosecond: 0})
      assert Types.advanced_type?(%Types.Neo4jDateTime{year: 2024, month: 1, day: 15, hour: 10, minute: 30, second: 45, nanosecond: 0, timezone_id: "UTC"})
      assert Types.advanced_type?(%Types.Neo4jLocalDateTime{year: 2024, month: 1, day: 15, hour: 10, minute: 30, second: 45, nanosecond: 0})
      assert Types.advanced_type?(%Types.Neo4jDuration{months: 0, days: 0, seconds: 0, nanoseconds: 0})
      assert Types.advanced_type?(DateTime.utc_now())
      assert Types.advanced_type?(Date.utc_today())
    end

    test "identifies non-advanced types correctly" do
      refute Types.advanced_type?("string")
      refute Types.advanced_type?(123)
      refute Types.advanced_type?(12.34)
      refute Types.advanced_type?([1, 2, 3])
      refute Types.advanced_type?(%{key: "value"})
      refute Types.advanced_type?(nil)
      refute Types.advanced_type?(true)
      refute Types.advanced_type?(false)
    end
  end

  describe "edge cases and error handling" do
    test "handles epoch date correctly" do
      epoch_date = %Types.Neo4jDate{year: 1970, month: 1, day: 1}
      encoded = Types.encode_date(epoch_date)
      assert encoded == [0]
      decoded = Types.decode_date(encoded)
      assert decoded == epoch_date
    end

    test "handles future dates correctly" do
      future_date = %Types.Neo4jDate{year: 2050, month: 12, day: 31}
      encoded = Types.encode_date(future_date)
      decoded = Types.decode_date(encoded)
      assert decoded == future_date
    end

    test "handles midnight time correctly" do
      midnight = %Types.Neo4jLocalTime{hour: 0, minute: 0, second: 0, nanosecond: 0}
      encoded = Types.encode_local_time(midnight)
      assert encoded == [0]
      decoded = Types.decode_local_time(encoded)
      assert decoded == midnight
    end

    test "handles maximum nanosecond precision" do
      max_nano_time = %Types.Neo4jLocalTime{
        hour: 23, minute: 59, second: 59, nanosecond: 999_999_999
      }
      encoded = Types.encode_local_time(max_nano_time)
      decoded = Types.decode_local_time(encoded)
      assert decoded == max_nano_time
    end

    test "handles zero duration correctly" do
      zero_duration = %Types.Neo4jDuration{months: 0, days: 0, seconds: 0, nanoseconds: 0}
      encoded = Types.encode_duration(zero_duration)
      assert encoded == [0, 0, 0, 0]
      decoded = Types.decode_duration(encoded)
      assert decoded == zero_duration
    end

    test "handles negative coordinates in points" do
      point = %Types.Point2D{x: -180.0, y: -90.0, srid: 4326}
      encoded = Types.encode_point(point)
      decoded = Types.decode_point(encoded)
      assert decoded == point
    end
  end

  describe "struct signature mapping" do
    test "PackStream uses correct signatures for encoding" do
      # Test that the correct struct signatures are used
      point_2d = %Types.Point2D{x: 1.0, y: 2.0, srid: 4326}
      encoded = PackStream.encode(point_2d)

      # The encoded binary should contain the signature 0x58 (88)
      <<_size_marker, 0x58, _rest::binary>> = encoded
    end

    test "PackStream decodes correct signatures" do
      # Create a manual struct with Point2D signature
      fields = [4326, 1.0, 2.0]
      encoded_fields = Enum.map(fields, &PackStream.encode/1) |> IO.iodata_to_binary()

      # Create a tiny struct with signature 0x58 and 3 fields
      manual_encoded = <<0xB3, 0x58, encoded_fields::binary>>

      {:ok, decoded, <<>>} = PackStream.decode(manual_encoded)
      assert %Types.Point2D{x: 1.0, y: 2.0, srid: 4326} = decoded
    end
  end

  describe "complex data structures" do
    test "handles maps containing advanced types" do
      data = %{
        "location" => %Types.Point2D{x: 40.7128, y: -74.0060, srid: 4326},
        "created" => %Types.Neo4jDate{year: 2024, month: 1, day: 15},
        "name" => "Test Location"
      }

      encoded = PackStream.encode(data)
      {:ok, decoded, <<>>} = PackStream.decode(encoded)

      assert decoded["location"] == data["location"]
      assert decoded["created"] == data["created"]
      assert decoded["name"] == data["name"]
    end

    test "handles lists containing advanced types" do
      data = [
        %Types.Point2D{x: 1.0, y: 2.0, srid: 4326},
        %Types.Point2D{x: 3.0, y: 4.0, srid: 4326},
        %Types.Neo4jDate{year: 2024, month: 1, day: 15}
      ]

      encoded = PackStream.encode(data)
      {:ok, decoded, <<>>} = PackStream.decode(encoded)

      assert decoded == data
    end
  end
end
