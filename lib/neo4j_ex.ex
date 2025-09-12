defmodule Neo4jEx do
  @moduledoc """
  Neo4j driver for Elixir.

  This module provides a high-level interface for connecting to and interacting with Neo4j databases
  using the Bolt protocol. It supports authentication, query execution, transactions, and connection pooling.

  ## Quick Start

      # Start a driver
      {:ok, driver} = Neo4jEx.start_link("bolt://localhost:7687",
        auth: {"neo4j", "password"})

      # Execute a simple query
      {:ok, results} = Neo4jEx.run(driver, "MATCH (n:Person) RETURN n.name LIMIT 10")

      # Work with sessions
      result = Neo4jEx.session(driver, fn session ->
        Neo4j.Session.run(session, "CREATE (p:Person {name: $name})", %{name: "Alice"})
      end)

      # Use transactions
      result = Neo4jEx.transaction(driver, fn tx ->
        Neo4j.Transaction.run(tx, "CREATE (p:Person {name: $name})", %{name: "Bob"})
        Neo4j.Transaction.run(tx, "CREATE (p:Person {name: $name})", %{name: "Carol"})
      end)

      # Stream large result sets
      driver
      |> Neo4jEx.stream("MATCH (n:Person) RETURN n")
      |> Stream.each(&process_record/1)
      |> Stream.run()

  ## Features

  - **Bolt Protocol Support**: Full implementation of Neo4j's Bolt protocol v5.x
  - **Authentication**: Support for basic authentication and no-auth scenarios
  - **Connection Management**: Automatic connection handling and cleanup
  - **Query Execution**: Simple query execution with parameter support
  - **Transactions**: Full transaction support with automatic commit/rollback
  - **Sessions**: Session-based query execution for better resource management
  - **Streaming**: Memory-efficient processing of large result sets
  - **Type Safety**: Proper handling of Neo4j data types and PackStream serialization
  - **Error Handling**: Comprehensive error handling and reporting

  ## Architecture

  The driver is built with a layered architecture:

  - **High-level API** (`Neo4jEx`, `Neo4j.Driver`): Simple interface for common operations
  - **Session Management** (`Neo4j.Session`): Session-based query execution
  - **Transaction Support** (`Neo4j.Transaction`): Transaction lifecycle management
  - **Streaming Support** (`Neo4jEx.Stream`): Memory-efficient processing of large datasets
  - **Protocol Layer** (`Neo4j.Protocol.*`): Bolt protocol implementation
  - **Connection Layer** (`Neo4j.Connection.*`): Low-level socket and handshake handling
  - **Type System** (`Neo4j.Types.*`, `Neo4j.Result.*`): Neo4j data type representations

  ## Configuration

  The driver supports various configuration options:

  - `:auth` - Authentication credentials (tuple or map)
  - `:user_agent` - Client identification string
  - `:connection_timeout` - Connection timeout in milliseconds
  - `:query_timeout` - Query timeout in milliseconds
  - `:max_pool_size` - Maximum number of connections (future feature)

  ## Examples

      # Basic usage
      {:ok, driver} = Neo4jEx.start_link("bolt://localhost:7687",
        auth: {"neo4j", "password"})

      # Create some data
      {:ok, _result} = Neo4jEx.run(driver, "
        CREATE (alice:Person {name: "Alice", age: 30})
        CREATE (bob:Person {name: "Bob", age: 25})
        CREATE (alice)-[:KNOWS]->(bob)
      "")

      # Query the data
      {:ok, results} = Neo4jEx.run(driver, "
        MATCH (p:Person)-[:KNOWS]->(friend:Person)
        RETURN p.name AS person, friend.name AS friend
      "")

      # Process results
      for record <- results.records do
        person = Neo4j.Result.Record.get(record, "person")
        friend = Neo4j.Result.Record.get(record, "friend")
        IO.puts('{person} knows {friend}"")
      end

      # Stream large result sets
      driver
      |> Neo4jEx.stream("MATCH (n:Person) RETURN n.name")
      |> Stream.map(fn record -> Neo4j.Result.Record.get(record, "n.name") end)
      |> Enum.each(&IO.puts/1)

      # Clean up
      Neo4jEx.close(driver)
  """

  alias Neo4j.Driver

  @doc """
  Starts a new Neo4j driver connection.

  This is a convenience function that delegates to `Neo4j.Driver.start_link/2`.

  ## Parameters
    - uri: Connection URI (e.g., "bolt://localhost:7687")
    - opts: Configuration options

  ## Options
    - `:auth` - Authentication tuple `{username, password}` or map
    - `:user_agent` - Client user agent string
    - `:connection_timeout` - Connection timeout in milliseconds
    - `:query_timeout` - Query timeout in milliseconds

  ## Returns
    - `{:ok, driver}` on success
    - `{:error, reason}` on failure

  ## Examples

      {:ok, driver} = Neo4jEx.start_link("bolt://localhost:7687",
        auth: {"neo4j", "password"})

      {:ok, driver} = Neo4jEx.start_link("bolt://localhost:7687",
        auth: %{"scheme" => "basic", "principal" => "neo4j", "credentials" => "password"})
  """
  def start_link(uri, opts \\ []) do
    Driver.start_link(uri, opts)
  end

  @doc """
  Executes a Cypher query directly using the driver.

  This is a convenience function that delegates to `Neo4j.Driver.run/4`.

  ## Parameters
    - driver: Driver process
    - query: Cypher query string
    - params: Query parameters map (default: %{})
    - opts: Query options (default: [])

  ## Returns
    - `{:ok, results}` on success where results contains records and summary
    - `{:error, reason}` on failure

  ## Examples

      {:ok, results} = Neo4jEx.run(driver, "MATCH (n:Person) RETURN n.name")
      {:ok, results} = Neo4jEx.run(driver, "CREATE (p:Person {name: $name})", %{name: "Alice"})
  """
  def run(driver, query, params \\ %{}, opts \\ []) do
    Driver.run(driver, query, params, opts)
  end

  @doc """
  Creates a stream for processing large result sets.

  This is a convenience function that delegates to `Neo4j.Stream.run/4`.

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
      |> Neo4jEx.stream("MATCH (n:Person) RETURN n")
      |> Stream.each(&process_record/1)
      |> Stream.run()

      # With custom batch size
      driver
      |> Neo4jEx.stream("MATCH (n:BigData) RETURN n", %{}, batch_size: 500)
      |> Stream.chunk_every(100)
      |> Enum.each(&batch_process/1)
  """
  def stream(driver, query, params \\ %{}, opts \\ []) do
    Neo4j.Stream.run(driver, query, params, opts)
  end

  @doc """
  Creates a session and executes the given function with it.

  This is a convenience function that delegates to `Neo4j.Driver.session/2`.

  ## Parameters
    - driver: Driver process
    - fun: Function that receives the session as an argument

  ## Returns
    Result of the function

  ## Examples

      result = Neo4jEx.session(driver, fn session ->
        Neo4j.Session.run(session, "MATCH (n:Person) RETURN count(n)")
      end)
  """
  def session(driver, fun) when is_function(fun, 1) do
    Driver.session(driver, fun)
  end

  @doc """
  Creates a transaction and executes the given function with it.

  This is a convenience function that delegates to `Neo4j.Driver.transaction/2`.

  ## Parameters
    - driver: Driver process
    - fun: Function that receives the transaction as an argument

  ## Returns
    Result of the function

  ## Examples

      result = Neo4jEx.transaction(driver, fn tx ->
        Neo4j.Transaction.run(tx, "CREATE (p:Person {name: $name})", %{name: "Bob"})
        Neo4j.Transaction.run(tx, "CREATE (p:Person {name: $name})", %{name: "Carol"})
      end)
  """
  def transaction(driver, fun) when is_function(fun, 1) do
    Driver.transaction(driver, fun)
  end

  @doc """
  Closes the driver and all its connections.

  This is a convenience function that delegates to `Neo4j.Driver.close/1`.

  ## Parameters
    - driver: Driver process

  ## Examples

      Neo4jEx.close(driver)
  """
  def close(driver) do
    Driver.close(driver)
  end

  @doc """
  Gets driver configuration.

  This is a convenience function that delegates to `Neo4j.Driver.get_config/1`.

  ## Parameters
    - driver: Driver process

  ## Returns
    Current driver configuration map

  ## Examples

      config = Neo4jEx.get_config(driver)
  """
  def get_config(driver) do
    Driver.get_config(driver)
  end

  @doc """
  Returns the version of the Neo4jEx library.

  ## Examples

      version = Neo4jEx.version()
      # => "0.1.0"
  """
  def version do
    Application.spec(:neo4j_ex, :vsn) |> to_string()
  end


end
