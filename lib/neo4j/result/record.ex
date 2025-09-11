defmodule Neo4j.Result.Record do
  @moduledoc """
  Represents a single record (row) returned from a Neo4j query.

  A record contains the values for each field in the query result.
  Records provide convenient access to field values by index or field name.

  ## Usage

      # Access by index
      value = Neo4j.Result.Record.get(record, 0)

      # Access by field name (when field names are available)
      value = Neo4j.Result.Record.get(record, "name")

      # Get all values
      values = Neo4j.Result.Record.values(record)

      # Convert to map (when field names are available)
      map = Neo4j.Result.Record.to_map(record, field_names)
  """

  defstruct [:values, :fields]

  @type t :: %__MODULE__{
    values: list(),
    fields: list(String.t()) | nil
  }

  @doc """
  Creates a new record from a list of values.

  ## Parameters
    - values: List of values for this record
    - fields: Optional list of field names (default: nil)

  ## Returns
    New record struct

  ## Examples

      record = Neo4j.Result.Record.new([1, "Alice", 25])
      record = Neo4j.Result.Record.new([1, "Alice", 25], ["id", "name", "age"])
  """
  def new(values, fields \\ nil) do
    %__MODULE__{
      values: values,
      fields: fields
    }
  end

  @doc """
  Gets a value from the record by index or field name.

  ## Parameters
    - record: Record struct
    - key: Integer index or string field name

  ## Returns
    - Value at the specified position
    - `nil` if index is out of bounds or field name not found

  ## Examples

      value = Neo4j.Result.Record.get(record, 0)
      value = Neo4j.Result.Record.get(record, "name")
  """
  def get(%__MODULE__{values: values}, key) when is_integer(key) do
    Enum.at(values, key)
  end

  def get(%__MODULE__{values: values, fields: fields}, key) when is_binary(key) do
    case fields do
      nil -> nil
      field_list ->
        case Enum.find_index(field_list, &(&1 == key)) do
          nil -> nil
          index -> Enum.at(values, index)
        end
    end
  end

  @doc """
  Gets all values from the record.

  ## Parameters
    - record: Record struct

  ## Returns
    List of all values in the record

  ## Examples

      values = Neo4j.Result.Record.values(record)
  """
  def values(%__MODULE__{values: values}) do
    values
  end

  @doc """
  Gets the field names for the record.

  ## Parameters
    - record: Record struct

  ## Returns
    - List of field names if available
    - `nil` if field names are not set

  ## Examples

      fields = Neo4j.Result.Record.fields(record)
  """
  def fields(%__MODULE__{fields: fields}) do
    fields
  end

  @doc """
  Converts the record to a map using field names as keys.

  ## Parameters
    - record: Record struct
    - field_names: Optional list of field names to use as keys

  ## Returns
    - Map with field names as keys and record values as values
    - Empty map if no field names are available

  ## Examples

      map = Neo4j.Result.Record.to_map(record)
      map = Neo4j.Result.Record.to_map(record, ["id", "name", "age"])
  """
  def to_map(%__MODULE__{values: values, fields: fields}, field_names \\ nil) do
    field_list = field_names || fields

    case field_list do
      nil -> %{}
      names when is_list(names) ->
        names
        |> Enum.zip(values)
        |> Enum.into(%{})
    end
  end

  @doc """
  Converts the record to a keyword list using field names as keys.

  ## Parameters
    - record: Record struct
    - field_names: Optional list of field names to use as keys

  ## Returns
    - Keyword list with field names as keys and record values as values
    - Empty list if no field names are available

  ## Examples

      keyword_list = Neo4j.Result.Record.to_keyword(record)
      keyword_list = Neo4j.Result.Record.to_keyword(record, ["id", "name", "age"])
  """
  def to_keyword(%__MODULE__{values: values, fields: fields}, field_names \\ nil) do
    field_list = field_names || fields

    case field_list do
      nil -> []
      names when is_list(names) ->
        names
        |> Enum.map(&String.to_atom/1)
        |> Enum.zip(values)
    end
  end

  @doc """
  Gets the number of values in the record.

  ## Parameters
    - record: Record struct

  ## Returns
    Number of values in the record

  ## Examples

      size = Neo4j.Result.Record.size(record)
  """
  def size(%__MODULE__{values: values}) do
    length(values)
  end

  @doc """
  Checks if the record is empty (has no values).

  ## Parameters
    - record: Record struct

  ## Returns
    `true` if the record has no values, `false` otherwise

  ## Examples

      empty? = Neo4j.Result.Record.empty?(record)
  """
  def empty?(%__MODULE__{values: values}) do
    Enum.empty?(values)
  end
end

# Implement Enumerable protocol for records
defimpl Enumerable, for: Neo4j.Result.Record do
  def count(%Neo4j.Result.Record{values: values}) do
    {:ok, length(values)}
  end

  def member?(%Neo4j.Result.Record{values: values}, element) do
    {:ok, Enum.member?(values, element)}
  end

  def slice(%Neo4j.Result.Record{values: values}) do
    {:ok, length(values), &Enum.slice(values, &1, &2)}
  end

  def reduce(%Neo4j.Result.Record{values: values}, acc, fun) do
    Enumerable.reduce(values, acc, fun)
  end
end
