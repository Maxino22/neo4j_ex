defmodule Neo4j.Types do
  @moduledoc """
  Neo4j advanced data type handling.

  This module provides support for Neo4j's advanced data types including:
  - Point types (2D and 3D spatial coordinates)
  - Temporal types (Date, Time, DateTime, Duration)

  ## Point Types

      # 2D Point
      point_2d = %Neo4j.Types.Point2D{x: 40.7128, y: -74.0060, srid: 4326}

      # 3D Point
      point_3d = %Neo4j.Types.Point3D{x: 40.7128, y: -74.0060, z: 10.5, srid: 4979}

  ## Temporal Types

      # Date
      date = %Neo4j.Types.Neo4jDate{year: 2024, month: 1, day: 15}

      # Time with timezone
      time = %Neo4j.Types.Neo4jTime{
        hour: 10, minute: 30, second: 45, nanosecond: 123456789,
        timezone_offset_seconds: -18000
      }

      # DateTime
      datetime = %Neo4j.Types.Neo4jDateTime{
        year: 2024, month: 1, day: 15,
        hour: 10, minute: 30, second: 45, nanosecond: 123456789,
        timezone_id: "America/New_York"
      }

      # Duration
      duration = %Neo4j.Types.Neo4jDuration{
        months: 12, days: 30, seconds: 3600, nanoseconds: 123456789
      }

  ## Usage in Queries

      # Create nodes with advanced types
      Neo4jEx.run(driver, \"\"\"
        CREATE (p:Place {
          name: $name,
          location: $point,
          created: $datetime
        })
      \"\"\", %{
        name: "Office",
        point: %Neo4j.Types.Point2D{x: 40.7128, y: -74.0060, srid: 4326},
        datetime: Neo4j.Types.from_elixir_datetime(DateTime.utc_now())
      })

      # Spatial queries
      Neo4jEx.run(driver, \"\"\"
        MATCH (p:Place)
        WHERE distance(p.location, $center) < $radius
        RETURN p.name, p.location
      \"\"\", %{
        center: %Neo4j.Types.Point2D{x: 40.7128, y: -74.0060, srid: 4326},
        radius: 1000
      })
  """

  # Point types
  defmodule Point2D do
    @moduledoc "Represents a 2D point with spatial reference system identifier."
    defstruct [:x, :y, :srid]
  end

  defmodule Point3D do
    @moduledoc "Represents a 3D point with spatial reference system identifier."
    defstruct [:x, :y, :z, :srid]
  end

  # Temporal types
  defmodule Neo4jDate do
    @moduledoc "Represents a Neo4j date."
    defstruct [:year, :month, :day]
  end

  defmodule Neo4jTime do
    @moduledoc "Represents a Neo4j time with timezone offset."
    defstruct [:hour, :minute, :second, :nanosecond, :timezone_offset_seconds]
  end

  defmodule Neo4jLocalTime do
    @moduledoc "Represents a Neo4j local time without timezone."
    defstruct [:hour, :minute, :second, :nanosecond]
  end

  defmodule Neo4jDateTime do
    @moduledoc "Represents a Neo4j datetime with timezone."
    defstruct [:year, :month, :day, :hour, :minute, :second, :nanosecond, :timezone_id]
  end

  defmodule Neo4jLocalDateTime do
    @moduledoc "Represents a Neo4j local datetime without timezone."
    defstruct [:year, :month, :day, :hour, :minute, :second, :nanosecond]
  end

  defmodule Neo4jDuration do
    @moduledoc "Represents a Neo4j duration."
    defstruct [:months, :days, :seconds, :nanoseconds]
  end

  @type point_2d :: %Point2D{
          x: float(),
          y: float(),
          srid: integer()
        }

  @type point_3d :: %Point3D{
          x: float(),
          y: float(),
          z: float(),
          srid: integer()
        }

  @type neo4j_date :: %Neo4jDate{
          year: integer(),
          month: integer(),
          day: integer()
        }

  @type neo4j_time :: %Neo4jTime{
          hour: integer(),
          minute: integer(),
          second: integer(),
          nanosecond: integer(),
          timezone_offset_seconds: integer()
        }

  @type neo4j_local_time :: %Neo4jLocalTime{
          hour: integer(),
          minute: integer(),
          second: integer(),
          nanosecond: integer()
        }

  @type neo4j_datetime :: %Neo4jDateTime{
          year: integer(),
          month: integer(),
          day: integer(),
          hour: integer(),
          minute: integer(),
          second: integer(),
          nanosecond: integer(),
          timezone_id: String.t()
        }

  @type neo4j_local_datetime :: %Neo4jLocalDateTime{
          year: integer(),
          month: integer(),
          day: integer(),
          hour: integer(),
          minute: integer(),
          second: integer(),
          nanosecond: integer()
        }

  @type neo4j_duration :: %Neo4jDuration{
          months: integer(),
          days: integer(),
          seconds: integer(),
          nanoseconds: integer()
        }

  # Common SRID values
  @wgs84_2d 4326
  @wgs84_3d 4979

  @doc """
  Creates a 2D point with WGS84 coordinate system (SRID 4326).

  ## Parameters
    - x: X coordinate (longitude for geographic coordinates)
    - y: Y coordinate (latitude for geographic coordinates)

  ## Examples

      point = Neo4j.Types.point_2d(40.7128, -74.0060)
  """
  def point_2d(x, y) when is_number(x) and is_number(y) do
    %Point2D{x: x / 1, y: y / 1, srid: @wgs84_2d}
  end

  @doc """
  Creates a 2D point with specified coordinate system.

  ## Parameters
    - x: X coordinate
    - y: Y coordinate
    - srid: Spatial Reference System Identifier

  ## Examples

      # Geographic coordinates (WGS84)
      geo_point = Neo4j.Types.point_2d(40.7128, -74.0060, 4326)

      # Cartesian coordinates
      cart_point = Neo4j.Types.point_2d(100.0, 200.0, 7203)
  """
  def point_2d(x, y, srid) when is_number(x) and is_number(y) and is_integer(srid) do
    %Point2D{x: x / 1, y: y / 1, srid: srid}
  end

  @doc """
  Creates a 3D point with WGS84 coordinate system (SRID 4979).

  ## Parameters
    - x: X coordinate (longitude for geographic coordinates)
    - y: Y coordinate (latitude for geographic coordinates)
    - z: Z coordinate (height/elevation)

  ## Examples

      point = Neo4j.Types.point_3d(40.7128, -74.0060, 10.5)
  """
  def point_3d(x, y, z) when is_number(x) and is_number(y) and is_number(z) do
    %Point3D{x: x / 1, y: y / 1, z: z / 1, srid: @wgs84_3d}
  end

  @doc """
  Creates a 3D point with specified coordinate system.

  ## Parameters
    - x: X coordinate
    - y: Y coordinate
    - z: Z coordinate
    - srid: Spatial Reference System Identifier

  ## Examples

      # Geographic coordinates (WGS84)
      geo_point = Neo4j.Types.point_3d(40.7128, -74.0060, 10.5, 4979)

      # Cartesian coordinates
      cart_point = Neo4j.Types.point_3d(100.0, 200.0, 50.0, 9157)
  """
  def point_3d(x, y, z, srid)
      when is_number(x) and is_number(y) and is_number(z) and is_integer(srid) do
    %Point3D{x: x / 1, y: y / 1, z: z / 1, srid: srid}
  end

  @doc """
  Converts an Elixir Date to Neo4j Date.

  ## Parameters
    - date: Elixir Date struct

  ## Examples

      neo4j_date = Neo4j.Types.from_elixir_date(~D[2024-01-15])
  """
  def from_elixir_date(%Date{year: year, month: month, day: day}) do
    %Neo4jDate{year: year, month: month, day: day}
  end

  @doc """
  Converts a Neo4j Date to Elixir Date.

  ## Parameters
    - neo4j_date: Neo4j Date struct

  ## Examples

      date = Neo4j.Types.to_elixir_date(neo4j_date)
  """
  def to_elixir_date(%Neo4jDate{year: year, month: month, day: day}) do
    Date.new!(year, month, day)
  end

  @doc """
  Converts an Elixir DateTime to Neo4j DateTime.

  ## Parameters
    - datetime: Elixir DateTime struct

  ## Examples

      neo4j_datetime = Neo4j.Types.from_elixir_datetime(DateTime.utc_now())
  """
  def from_elixir_datetime(%DateTime{} = dt) do
    %Neo4jDateTime{
      year: dt.year,
      month: dt.month,
      day: dt.day,
      hour: dt.hour,
      minute: dt.minute,
      second: dt.second,
      nanosecond: dt.microsecond |> elem(0) |> Kernel.*(1000),
      timezone_id: dt.time_zone
    }
  end

  @doc """
  Converts a Neo4j DateTime to Elixir DateTime.

  ## Parameters
    - neo4j_datetime: Neo4j DateTime struct

  ## Examples

      datetime = Neo4j.Types.to_elixir_datetime(neo4j_datetime)
  """
  def to_elixir_datetime(%Neo4jDateTime{} = dt) do
    microsecond = {div(dt.nanosecond, 1000), 6}

    DateTime.new!(
      Date.new!(dt.year, dt.month, dt.day),
      Time.new!(dt.hour, dt.minute, dt.second, microsecond),
      dt.timezone_id
    )
  end

  @doc """
  Decodes Neo4j point data from PackStream format.

  ## Parameters
    - point_data: List containing point coordinates and metadata

  ## Examples

      point = Neo4j.Types.decode_point([4326, 40.7128, -74.0060])
  """
  def decode_point([srid, x, y]) do
    %Point2D{x: x, y: y, srid: srid}
  end

  def decode_point([srid, x, y, z]) do
    %Point3D{x: x, y: y, z: z, srid: srid}
  end

  @doc """
  Encodes a Point struct to Neo4j format.

  ## Parameters
    - point: Point2D or Point3D struct

  ## Examples

      encoded = Neo4j.Types.encode_point(point_2d)
  """
  def encode_point(%Point2D{x: x, y: y, srid: srid}) do
    [srid, x, y]
  end

  def encode_point(%Point3D{x: x, y: y, z: z, srid: srid}) do
    [srid, x, y, z]
  end

  @doc """
  Decodes Neo4j date data from PackStream format.

  ## Parameters
    - date_data: List containing date components

  ## Examples

      date = Neo4j.Types.decode_date([18628])  # Days since epoch
  """
  def decode_date([days_since_epoch]) do
    # Neo4j epoch is 1970-01-01, same as Unix epoch
    base_date = ~D[1970-01-01]
    date = Date.add(base_date, days_since_epoch)
    %Neo4jDate{year: date.year, month: date.month, day: date.day}
  end

  @doc """
  Encodes a Neo4j Date to PackStream format.

  ## Parameters
    - date: Neo4jDate struct

  ## Examples

      encoded = Neo4j.Types.encode_date(neo4j_date)
  """
  def encode_date(%Neo4jDate{year: year, month: month, day: day}) do
    date = Date.new!(year, month, day)
    base_date = ~D[1970-01-01]
    days_since_epoch = Date.diff(date, base_date)
    [days_since_epoch]
  end

  @doc """
  Decodes Neo4j time data from PackStream format.

  ## Parameters
    - time_data: List containing time components

  ## Examples

      time = Neo4j.Types.decode_time([43845123456789, -18000])
  """
  def decode_time([nanoseconds_since_midnight, timezone_offset_seconds]) do
    total_seconds = div(nanoseconds_since_midnight, 1_000_000_000)
    remaining_nanos = rem(nanoseconds_since_midnight, 1_000_000_000)

    hour = div(total_seconds, 3600)
    minute = div(rem(total_seconds, 3600), 60)
    second = rem(total_seconds, 60)

    %Neo4jTime{
      hour: hour,
      minute: minute,
      second: second,
      nanosecond: remaining_nanos,
      timezone_offset_seconds: timezone_offset_seconds
    }
  end

  @doc """
  Encodes a Neo4j Time to PackStream format.

  ## Parameters
    - time: Neo4jTime struct

  ## Examples

      encoded = Neo4j.Types.encode_time(neo4j_time)
  """
  def encode_time(%Neo4jTime{} = time) do
    nanoseconds_since_midnight =
      time.hour * 3_600_000_000_000 +
        time.minute * 60_000_000_000 +
        time.second * 1_000_000_000 +
        time.nanosecond

    [nanoseconds_since_midnight, time.timezone_offset_seconds]
  end

  @doc """
  Decodes Neo4j local time data from PackStream format.

  ## Parameters
    - local_time_data: List containing local time components

  ## Examples

      local_time = Neo4j.Types.decode_local_time([43845123456789])
  """
  def decode_local_time([nanoseconds_since_midnight]) do
    total_seconds = div(nanoseconds_since_midnight, 1_000_000_000)
    remaining_nanos = rem(nanoseconds_since_midnight, 1_000_000_000)

    hour = div(total_seconds, 3600)
    minute = div(rem(total_seconds, 3600), 60)
    second = rem(total_seconds, 60)

    %Neo4jLocalTime{
      hour: hour,
      minute: minute,
      second: second,
      nanosecond: remaining_nanos
    }
  end

  @doc """
  Encodes a Neo4j LocalTime to PackStream format.

  ## Parameters
    - local_time: Neo4jLocalTime struct

  ## Examples

      encoded = Neo4j.Types.encode_local_time(neo4j_local_time)
  """
  def encode_local_time(%Neo4jLocalTime{} = time) do
    nanoseconds_since_midnight =
      time.hour * 3_600_000_000_000 +
        time.minute * 60_000_000_000 +
        time.second * 1_000_000_000 +
        time.nanosecond

    [nanoseconds_since_midnight]
  end

  @doc """
  Decodes Neo4j datetime data from PackStream format.

  ## Parameters
    - datetime_data: List containing datetime components

  ## Examples

      datetime = Neo4j.Types.decode_datetime([1705320645, 123456789, "America/New_York"])
  """
  def decode_datetime([epoch_seconds, nanosecond, timezone_id]) do
    datetime = DateTime.from_unix!(epoch_seconds)

    %Neo4jDateTime{
      year: datetime.year,
      month: datetime.month,
      day: datetime.day,
      hour: datetime.hour,
      minute: datetime.minute,
      second: datetime.second,
      nanosecond: nanosecond,
      timezone_id: timezone_id
    }
  end

  @doc """
  Encodes a Neo4j DateTime to PackStream format.

  ## Parameters
    - datetime: Neo4jDateTime struct

  ## Examples

      encoded = Neo4j.Types.encode_datetime(neo4j_datetime)
  """
  def encode_datetime(%Neo4jDateTime{} = dt) do
    # Create a naive datetime first, then convert to UTC for epoch calculation
    naive_datetime =
      NaiveDateTime.new!(
        Date.new!(dt.year, dt.month, dt.day),
        Time.new!(dt.hour, dt.minute, dt.second)
      )

    # Convert to UTC datetime for epoch calculation
    utc_datetime = DateTime.from_naive!(naive_datetime, "Etc/UTC")
    epoch_seconds = DateTime.to_unix(utc_datetime)
    [epoch_seconds, dt.nanosecond, dt.timezone_id]
  end

  @doc """
  Decodes Neo4j local datetime data from PackStream format.

  ## Parameters
    - local_datetime_data: List containing local datetime components

  ## Examples

      local_datetime = Neo4j.Types.decode_local_datetime([1705320645, 123456789])
  """
  def decode_local_datetime([epoch_seconds, nanosecond]) do
    datetime = DateTime.from_unix!(epoch_seconds)

    %Neo4jLocalDateTime{
      year: datetime.year,
      month: datetime.month,
      day: datetime.day,
      hour: datetime.hour,
      minute: datetime.minute,
      second: datetime.second,
      nanosecond: nanosecond
    }
  end

  @doc """
  Encodes a Neo4j LocalDateTime to PackStream format.

  ## Parameters
    - local_datetime: Neo4jLocalDateTime struct

  ## Examples

      encoded = Neo4j.Types.encode_local_datetime(neo4j_local_datetime)
  """
  def encode_local_datetime(%Neo4jLocalDateTime{} = dt) do
    datetime =
      DateTime.new!(
        Date.new!(dt.year, dt.month, dt.day),
        Time.new!(dt.hour, dt.minute, dt.second),
        "Etc/UTC"
      )

    epoch_seconds = DateTime.to_unix(datetime)
    [epoch_seconds, dt.nanosecond]
  end

  @doc """
  Decodes Neo4j duration data from PackStream format.

  ## Parameters
    - duration_data: List containing duration components

  ## Examples

      duration = Neo4j.Types.decode_duration([12, 30, 3600, 123456789])
  """
  def decode_duration([months, days, seconds, nanoseconds]) do
    %Neo4jDuration{
      months: months,
      days: days,
      seconds: seconds,
      nanoseconds: nanoseconds
    }
  end

  @doc """
  Encodes a Neo4j Duration to PackStream format.

  ## Parameters
    - duration: Neo4jDuration struct

  ## Examples

      encoded = Neo4j.Types.encode_duration(neo4j_duration)
  """
  def encode_duration(%Neo4jDuration{
        months: months,
        days: days,
        seconds: seconds,
        nanoseconds: nanoseconds
      }) do
    [months, days, seconds, nanoseconds]
  end

  @doc """
  Checks if a value is an advanced Neo4j type that needs special encoding.

  ## Parameters
    - value: Any value to check

  ## Examples

      Neo4j.Types.advanced_type?(%Neo4j.Types.Point2D{}) # => true
      Neo4j.Types.advanced_type?("string") # => false
  """
  def advanced_type?(%Point2D{}), do: true
  def advanced_type?(%Point3D{}), do: true
  def advanced_type?(%Neo4jDate{}), do: true
  def advanced_type?(%Neo4jTime{}), do: true
  def advanced_type?(%Neo4jLocalTime{}), do: true
  def advanced_type?(%Neo4jDateTime{}), do: true
  def advanced_type?(%Neo4jLocalDateTime{}), do: true
  def advanced_type?(%Neo4jDuration{}), do: true
  def advanced_type?(%DateTime{}), do: true
  def advanced_type?(%Date{}), do: true
  def advanced_type?(_), do: false
end
