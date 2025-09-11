defmodule Neo4j.Result.Summary do
  @moduledoc """
  Represents the summary of a Neo4j query execution.

  The summary contains metadata about the query execution, including
  statistics, timing information, and any notifications or warnings.

  ## Usage

      # Access summary information
      stats = Neo4j.Result.Summary.counters(summary)
      query_type = Neo4j.Result.Summary.query_type(summary)
      notifications = Neo4j.Result.Summary.notifications(summary)
  """

  defstruct [
    :query_type,
    :counters,
    :plan,
    :profile,
    :notifications,
    :result_available_after,
    :result_consumed_after,
    :server,
    :database
  ]

  @type t :: %__MODULE__{
    query_type: String.t() | nil,
    counters: map() | nil,
    plan: map() | nil,
    profile: map() | nil,
    notifications: list() | nil,
    result_available_after: integer() | nil,
    result_consumed_after: integer() | nil,
    server: map() | nil,
    database: String.t() | nil
  }

  @doc """
  Creates a new summary from metadata.

  ## Parameters
    - metadata: Map containing summary metadata from Neo4j

  ## Returns
    New summary struct

  ## Examples

      summary = Neo4j.Result.Summary.new(metadata)
  """
  def new(metadata) when is_map(metadata) do
    %__MODULE__{
      query_type: metadata["type"],
      counters: metadata["stats"],
      plan: metadata["plan"],
      profile: metadata["profile"],
      notifications: metadata["notifications"],
      result_available_after: metadata["result_available_after"],
      result_consumed_after: metadata["result_consumed_after"],
      server: metadata["server"],
      database: metadata["db"]
    }
  end

  @doc """
  Gets the query type from the summary.

  ## Parameters
    - summary: Summary struct

  ## Returns
    - Query type string (e.g., "r" for read, "w" for write, "rw" for read-write)
    - `nil` if not available

  ## Examples

      query_type = Neo4j.Result.Summary.query_type(summary)
  """
  def query_type(%__MODULE__{query_type: query_type}) do
    query_type
  end

  @doc """
  Gets the statistics counters from the summary.

  ## Parameters
    - summary: Summary struct

  ## Returns
    - Map containing statistics counters
    - `nil` if not available

  ## Examples

      counters = Neo4j.Result.Summary.counters(summary)
      nodes_created = counters["nodes_created"]
  """
  def counters(%__MODULE__{counters: counters}) do
    counters
  end

  @doc """
  Gets the query plan from the summary.

  ## Parameters
    - summary: Summary struct

  ## Returns
    - Map containing query plan information
    - `nil` if not available

  ## Examples

      plan = Neo4j.Result.Summary.plan(summary)
  """
  def plan(%__MODULE__{plan: plan}) do
    plan
  end

  @doc """
  Gets the query profile from the summary.

  ## Parameters
    - summary: Summary struct

  ## Returns
    - Map containing query profile information
    - `nil` if not available

  ## Examples

      profile = Neo4j.Result.Summary.profile(summary)
  """
  def profile(%__MODULE__{profile: profile}) do
    profile
  end

  @doc """
  Gets the notifications from the summary.

  ## Parameters
    - summary: Summary struct

  ## Returns
    - List of notification maps
    - `nil` if not available

  ## Examples

      notifications = Neo4j.Result.Summary.notifications(summary)
  """
  def notifications(%__MODULE__{notifications: notifications}) do
    notifications || []
  end

  @doc """
  Gets the time when results became available.

  ## Parameters
    - summary: Summary struct

  ## Returns
    - Time in milliseconds when results became available
    - `nil` if not available

  ## Examples

      available_after = Neo4j.Result.Summary.result_available_after(summary)
  """
  def result_available_after(%__MODULE__{result_available_after: time}) do
    time
  end

  @doc """
  Gets the time when results were consumed.

  ## Parameters
    - summary: Summary struct

  ## Returns
    - Time in milliseconds when results were consumed
    - `nil` if not available

  ## Examples

      consumed_after = Neo4j.Result.Summary.result_consumed_after(summary)
  """
  def result_consumed_after(%__MODULE__{result_consumed_after: time}) do
    time
  end

  @doc """
  Gets the server information from the summary.

  ## Parameters
    - summary: Summary struct

  ## Returns
    - Map containing server information
    - `nil` if not available

  ## Examples

      server = Neo4j.Result.Summary.server(summary)
      version = server["version"]
  """
  def server(%__MODULE__{server: server}) do
    server
  end

  @doc """
  Gets the database name from the summary.

  ## Parameters
    - summary: Summary struct

  ## Returns
    - Database name string
    - `nil` if not available

  ## Examples

      database = Neo4j.Result.Summary.database(summary)
  """
  def database(%__MODULE__{database: database}) do
    database
  end

  @doc """
  Checks if the query contained updates (writes).

  ## Parameters
    - summary: Summary struct

  ## Returns
    `true` if the query contained updates, `false` otherwise

  ## Examples

      contains_updates? = Neo4j.Result.Summary.contains_updates?(summary)
  """
  def contains_updates?(%__MODULE__{counters: counters}) when is_map(counters) do
    update_keys = [
      "nodes_created", "nodes_deleted",
      "relationships_created", "relationships_deleted",
      "properties_set", "labels_added", "labels_removed",
      "indexes_added", "indexes_removed",
      "constraints_added", "constraints_removed"
    ]

    Enum.any?(update_keys, fn key ->
      case Map.get(counters, key) do
        nil -> false
        0 -> false
        _ -> true
      end
    end)
  end

  def contains_updates?(%__MODULE__{counters: nil}) do
    false
  end

  @doc """
  Checks if the query contained system updates.

  ## Parameters
    - summary: Summary struct

  ## Returns
    `true` if the query contained system updates, `false` otherwise

  ## Examples

      contains_system_updates? = Neo4j.Result.Summary.contains_system_updates?(summary)
  """
  def contains_system_updates?(%__MODULE__{counters: counters}) when is_map(counters) do
    system_update_keys = [
      "system_updates"
    ]

    Enum.any?(system_update_keys, fn key ->
      case Map.get(counters, key) do
        nil -> false
        0 -> false
        _ -> true
      end
    end)
  end

  def contains_system_updates?(%__MODULE__{counters: nil}) do
    false
  end

  @doc """
  Gets a specific counter value.

  ## Parameters
    - summary: Summary struct
    - counter_name: Name of the counter to retrieve

  ## Returns
    - Counter value (integer)
    - 0 if counter not found

  ## Examples

      nodes_created = Neo4j.Result.Summary.get_counter(summary, "nodes_created")
  """
  def get_counter(%__MODULE__{counters: counters}, counter_name) when is_map(counters) do
    Map.get(counters, counter_name, 0)
  end

  def get_counter(%__MODULE__{counters: nil}, _counter_name) do
    0
  end

  @doc """
  Converts the summary to a map.

  ## Parameters
    - summary: Summary struct

  ## Returns
    Map representation of the summary

  ## Examples

      map = Neo4j.Result.Summary.to_map(summary)
  """
  def to_map(%__MODULE__{} = summary) do
    Map.from_struct(summary)
  end
end
