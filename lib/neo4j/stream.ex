defmodule Neo4j.Stream do
  @moduledoc """
  Streaming interface for large Neo4j result sets.

  This module provides a way to process large result sets without loading all data
  into memory at once. It uses Elixir's Stream.resource/3 to create a stream
  that fetches data in batches using Neo4j's SKIP/LIMIT pagination.
  """

  alias Neo4j.Driver
  alias Neo4j.Session

  @doc """
  Creates a stream for large result sets.

  ## Parameters
    - driver: Driver process
    - query: Cypher query string
    - params: Query parameters map (default: %{})
    - opts: Query options (default: [])

  ## Options
    - `:batch_size` - Number of records to fetch at once (default: 1000)
    - `:timeout` - Query timeout in milliseconds (default: 30000)

  ## Returns
    Stream of records

  ## Examples

      # Basic streaming
      driver
      |> Neo4j.Stream.run(\"MATCH (n:Person) RETURN n\")
      |> Stream.map(fn record -> process_person(record) end)
      |> Stream.run()

      # With custom batch size
      driver
      |> Neo4j.Stream.run(\"MATCH (n:BigData) RETURN n\", %{}, batch_size: 500)
      |> Stream.chunk_every(100)
      |> Enum.each(&batch_process/1)

      # Memory-efficient aggregation
      total = driver
      |> Neo4j.Stream.run(\"MATCH (n:Transaction) RETURN n.amount\")
      |> Stream.map(fn record -> record |> get_field(\"n.amount\") end)
      |> Enum.sum()
  """
  def run(driver, query, params \\ %{}, opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, 1000)
    timeout = Keyword.get(opts, :timeout, 30000)

    Stream.resource(
      fn ->
        # Start state: {skip, continue_fetching}
        {0, true, driver, query, params, batch_size, timeout}
      end,
      fn {skip, continue_fetching, driver, query, params, batch_size, timeout} ->
        if continue_fetching do
          case fetch_batch(driver, query, params, skip, batch_size, timeout) do
            {:ok, records, batch_count} ->
              new_skip = skip + batch_count
              # Continue if we got a full batch AND there are records, stop if we got fewer records than requested
              continue_fetching = batch_count > 0 && batch_count == batch_size
              {records, {new_skip, continue_fetching, driver, query, params, batch_size, timeout}}
            {:error, reason} ->
              {:halt, reason}
          end
        else
          {:halt, :done}
        end
      end,
      fn _state ->
        # Cleanup function - no specific cleanup needed
        :ok
      end
    )
    # Flatten the batches into individual records
    |> Stream.flat_map(& &1)
  end

  @doc """
  Stream with custom processing function.

  ## Parameters
    - driver: Driver process
    - query: Cypher query string
    - params: Query parameters map (default: %{})
    - processor_fn: Function to process each record
    - opts: Query options (default: [])

  ## Options
    - `:batch_size` - Number of records to fetch at once (default: 1000)
    - `:timeout` - Query timeout in milliseconds (default: 30000)

  ## Returns
    Stream of processed records
  """
  def run_with(driver, query, params \\ %{}, processor_fn, opts \\ []) do
    run(driver, query, params, opts)
    |> Stream.map(processor_fn)
  end

  # Private Functions

  defp fetch_batch(driver, query, params, skip, limit, timeout) do
    Driver.session(driver, fn session ->
      # Modify the query to add SKIP and LIMIT
      paginated_query = add_pagination_to_query(query, skip, limit)

      case Session.run(session, paginated_query, params, timeout: timeout) do
        {:ok, %{records: records}} ->
          # Return records with batch info - no need for total count
          {:ok, records, length(records)}
        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  defp add_pagination_to_query(query, skip, limit) do
    # Add SKIP and LIMIT to the query
    # This is a simple approach - in a real implementation, we'd need to be more careful
    # about query parsing to ensure we're adding it correctly
    String.trim(query) <> " SKIP #{skip} LIMIT #{limit}"
  end

end
