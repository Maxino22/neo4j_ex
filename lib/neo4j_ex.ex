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
  alias Neo4j.Registry

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
  Executes a Cypher query using the default driver.

  This function uses the `:default` driver automatically. If you need to use
  a different driver, use the 4-arity version instead.

  ## Parameters
    - query: Cypher query string

  ## Returns
    - `{:ok, results}` on success where results contains records and summary
    - `{:error, reason}` on failure

  ## Examples

      # Uses :default driver automatically
      {:ok, results} = Neo4jEx.run("MATCH (n:Person) RETURN n.name")
  """
  def run(query) when is_binary(query) do
    run(:default, query, %{}, [])
  end

  @doc """
  Executes a Cypher query using the default driver with parameters.

  This function uses the `:default` driver automatically. If you need to use
  a different driver, use the 4-arity version instead.

  ## Parameters
    - query: Cypher query string
    - params: Query parameters map

  ## Returns
    - `{:ok, results}` on success where results contains records and summary
    - `{:error, reason}` on failure

  ## Examples

      # Uses :default driver automatically
      {:ok, results} = Neo4jEx.run("CREATE (p:Person {name: $name})", %{name: "Alice"})
  """
  def run(query, params) when is_binary(query) and is_map(params) do
    run(:default, query, params, [])
  end

  @doc """
  Executes a Cypher query using the default driver with parameters and options.

  This function uses the `:default` driver automatically. If you need to use
  a different driver, use the 4-arity version instead.

  ## Parameters
    - query: Cypher query string
    - params: Query parameters map
    - opts: Query options

  ## Returns
    - `{:ok, results}` on success where results contains records and summary
    - `{:error, reason}` on failure

  ## Examples

      # Uses :default driver automatically
      {:ok, results} = Neo4jEx.run("CREATE (p:Person {name: $name})", %{name: "Alice"}, timeout: 5000)
  """
  def run(query, params, opts) when is_binary(query) and is_map(params) and is_list(opts) do
    run(:default, query, params, opts)
  end

  @doc """
  Executes a Cypher query directly using the specified driver.

  This is a convenience function that delegates to `Neo4j.Driver.run/4`.

  ## Parameters
    - driver: Driver process or driver name (atom)
    - query: Cypher query string
    - params: Query parameters map (default: %{})
    - opts: Query options (default: [])

  ## Returns
    - `{:ok, results}` on success where results contains records and summary
    - `{:error, reason}` on failure

  ## Examples

      {:ok, results} = Neo4jEx.run(driver, "MATCH (n:Person) RETURN n.name")
      {:ok, results} = Neo4jEx.run(:default, "MATCH (n:Person) RETURN n.name")
      {:ok, results} = Neo4jEx.run(:analytics, "CREATE (p:Person {name: $name})", %{name: "Alice"})
  """
  def run(driver, query, params \\ %{}, opts \\ []) do
    with {:ok, resolved_driver} <- resolve_driver(driver) do
      Driver.run(resolved_driver, query, params, opts)
    end
  end

  @doc """
  Creates a stream for processing large result sets using the default driver.

  This function uses the `:default` driver automatically. If you need to use
  a different driver, use the 4-arity version instead.

  ## Parameters
    - query: Cypher query string

  ## Returns
    Stream of records

  ## Examples

      # Uses :default driver automatically
      Neo4jEx.stream("MATCH (n:Person) RETURN n")
      |> Stream.each(&process_record/1)
      |> Stream.run()
  """
  def stream(query) when is_binary(query) do
    stream(:default, query, %{}, [])
  end

  @doc """
  Creates a stream for processing large result sets using the default driver with parameters.

  This function uses the `:default` driver automatically. If you need to use
  a different driver, use the 4-arity version instead.

  ## Parameters
    - query: Cypher query string
    - params: Query parameters map

  ## Returns
    Stream of records

  ## Examples

      # Uses :default driver automatically
      Neo4jEx.stream("MATCH (n:Person {age: $age}) RETURN n", %{age: 30})
      |> Stream.each(&process_record/1)
      |> Stream.run()
  """
  def stream(query, params) when is_binary(query) and is_map(params) do
    stream(:default, query, params, [])
  end

  @doc """
  Creates a stream for processing large result sets using the default driver with parameters and options.

  This function uses the `:default` driver automatically. If you need to use
  a different driver, use the 4-arity version instead.

  ## Parameters
    - query: Cypher query string
    - params: Query parameters map
    - opts: Query options

  ## Returns
    Stream of records

  ## Examples

      # Uses :default driver automatically
      Neo4jEx.stream("MATCH (n:Person {age: $age}) RETURN n", %{age: 30}, batch_size: 500)
      |> Stream.each(&process_record/1)
      |> Stream.run()
  """
  def stream(query, params, opts) when is_binary(query) and is_map(params) and is_list(opts) do
    stream(:default, query, params, opts)
  end

  @doc """
  Creates a stream for processing large result sets.

  This is a convenience function that delegates to `Neo4j.Stream.run/4`.

  ## Parameters
    - driver: Driver process or driver name (atom)
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
    with {:ok, resolved_driver} <- resolve_driver(driver) do
      Neo4j.Stream.run(resolved_driver, query, params, opts)
    end
  end

  @doc """
  Creates a session using the default driver and executes the given function with it.

  This function uses the `:default` driver automatically. If you need to use
  a different driver, use the 2-arity version instead.

  ## Parameters
    - fun: Function that receives the session as an argument

  ## Returns
    Result of the function

  ## Examples

      # Uses :default driver automatically
      result = Neo4jEx.session(fn session ->
        Neo4j.Session.run(session, "MATCH (n:Person) RETURN count(n)")
      end)
  """
  def session(fun) when is_function(fun, 1) do
    session(:default, fun)
  end

  @doc """
  Creates a session and executes the given function with it.

  This is a convenience function that delegates to `Neo4j.Driver.session/2`.

  ## Parameters
    - driver: Driver process or driver name (atom)
    - fun: Function that receives the session as an argument

  ## Returns
    Result of the function

  ## Examples

      result = Neo4jEx.session(driver, fn session ->
        Neo4j.Session.run(session, "MATCH (n:Person) RETURN count(n)")
      end)

      result = Neo4jEx.session(:default, fn session ->
        Neo4j.Session.run(session, "MATCH (n:Person) RETURN count(n)")
      end)
  """
  def session(driver, fun) when is_function(fun, 1) do
    with {:ok, resolved_driver} <- resolve_driver(driver) do
      Driver.session(resolved_driver, fun)
    end
  end

  @doc """
  Creates a transaction using the default driver and executes the given function with it.

  This function uses the `:default` driver automatically. If you need to use
  a different driver, use the 2-arity version instead.

  ## Parameters
    - fun: Function that receives the transaction as an argument

  ## Returns
    Result of the function

  ## Examples

      # Uses :default driver automatically
      result = Neo4jEx.transaction(fn tx ->
        Neo4j.Transaction.run(tx, "CREATE (p:Person {name: $name})", %{name: "Bob"})
        Neo4j.Transaction.run(tx, "CREATE (p:Person {name: $name})", %{name: "Carol"})
      end)
  """
  def transaction(fun) when is_function(fun, 1) do
    transaction(:default, fun)
  end

  @doc """
  Creates a transaction and executes the given function with it.

  This is a convenience function that delegates to `Neo4j.Driver.transaction/2`.

  ## Parameters
    - driver: Driver process or driver name (atom)
    - fun: Function that receives the transaction as an argument

  ## Returns
    Result of the function

  ## Examples

      result = Neo4jEx.transaction(driver, fn tx ->
        Neo4j.Transaction.run(tx, "CREATE (p:Person {name: $name})", %{name: "Bob"})
        Neo4j.Transaction.run(tx, "CREATE (p:Person {name: $name})", %{name: "Carol"})
      end)

      result = Neo4jEx.transaction(:analytics, fn tx ->
        Neo4j.Transaction.run(tx, "CREATE (p:Person {name: $name})", %{name: "Bob"})
      end)
  """
  def transaction(driver, fun) when is_function(fun, 1) do
    with {:ok, resolved_driver} <- resolve_driver(driver) do
      Driver.transaction(resolved_driver, fun)
    end
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

  # Connection Pool API

  @doc """
  Start a connection pool.

  This is a convenience function that delegates to `Neo4j.Connection.Pool.start_pool/1`.

  ## Options
  - `:uri` - Neo4j connection URI (required)
  - `:auth` - Authentication tuple `{username, password}` or map
  - `:pool_size` - Maximum number of connections (default: 10)
  - `:max_overflow` - Maximum overflow connections (default: 5)
  - `:user_agent` - Client user agent string
  - `:connection_timeout` - Connection timeout in milliseconds
  - `:query_timeout` - Query timeout in milliseconds
  - `:name` - Pool name (optional)

  ## Examples

      {:ok, _pool} = Neo4jEx.start_pool([
        uri: "bolt://localhost:7687",
        auth: {"neo4j", "password"},
        pool_size: 15,
        max_overflow: 5
      ])
  """
  def start_pool(opts) do
    Neo4j.Connection.Pool.start_pool(opts)
  end

  @doc """
  Stop a connection pool.

  This is a convenience function that delegates to `Neo4j.Connection.Pool.stop_pool/1`.

  ## Parameters
  - `pool_name` - Pool name (default: Neo4j.Connection.Pool)
  """
  def stop_pool(pool_name \\ Neo4j.Connection.Pool) do
    Neo4j.Connection.Pool.stop_pool(pool_name)
  end

  # Private Functions

  defp resolve_driver(driver_ref) do
    Registry.lookup(driver_ref)
  end

  defmodule Pool do
    @doc """
    Execute a query using a pooled connection.

    ## Parameters
    - `query` - Cypher query string
    - `params` - Query parameters map (default: %{})
    - `opts` - Query options (default: [])

    ## Examples

        {:ok, results} = Neo4jEx.Pool.run("MATCH (n:Person) RETURN n")
        {:ok, results} = Neo4jEx.Pool.run("CREATE (p:Person {name: $name})", %{name: "Alice"})
    """
    def run(query, params \\ %{}, opts \\ []) do
      Neo4j.Connection.Pool.run(query, params, opts)
    end

    @doc """
    Execute a function within a transaction using a pooled connection.

    ## Parameters
    - `fun` - Function to execute within the transaction
    - `opts` - Transaction options (default: [])

    ## Examples

        Neo4jEx.Pool.transaction(fn ->
          Neo4jEx.Pool.run("CREATE (p:Person {name: 'Alice'})")
          Neo4jEx.Pool.run("CREATE (p:Person {name: 'Bob'})")
        end)
    """
    def transaction(fun, opts \\ []) when is_function(fun, 0) do
      Neo4j.Connection.Pool.transaction(fun, opts)
    end

    @doc """
    Get pool status information.

    ## Parameters
    - `pool_name` - Pool name (default: Neo4j.Connection.Pool)

    ## Returns
    Map with pool status information
    """
    def status(pool_name \\ Neo4j.Connection.Pool) do
      Neo4j.Connection.Pool.status(pool_name)
    end
  end

end
