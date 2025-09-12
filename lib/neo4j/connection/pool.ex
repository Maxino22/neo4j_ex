defmodule Neo4j.Connection.Pool do
  @moduledoc """
  Connection pool for Neo4j drivers using poolboy.

  This module provides connection pooling functionality to improve performance
  and resource management when working with Neo4j databases.

  ## Usage

      # Start a connection pool
      {:ok, _pool} = Neo4j.Connection.Pool.start_pool([
        uri: "bolt://localhost:7687",
        auth: {"neo4j", "password"},
        pool_size: 15,
        max_overflow: 5
      ])

      # Execute queries using the pool
      {:ok, results} = Neo4j.Connection.Pool.run("MATCH (n:Person) RETURN n")

      # Execute transactions using the pool
      Neo4j.Connection.Pool.transaction(fn ->
        Neo4j.Connection.Pool.run("CREATE (p:Person {name: 'Alice'})")
        Neo4j.Connection.Pool.run("CREATE (p:Person {name: 'Bob'})")
      end)
  """

  require Logger

  @default_pool_config %{
    pool_size: 10,
    max_overflow: 5,
    strategy: :fifo
  }

  @default_connection_config %{
    host: "localhost",
    port: 7687,
    auth: nil,
    user_agent: "neo4j_ex/0.1.0",
    connection_timeout: 15_000,
    query_timeout: 30_000
  }

  # Client API

  @doc """
  Start a connection pool.

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

      {:ok, _pool} = Neo4j.Connection.Pool.start_pool([
        uri: "bolt://localhost:7687",
        auth: {"neo4j", "password"},
        pool_size: 15,
        max_overflow: 5
      ])
  """
  def start_pool(opts) do
    with {:ok, uri} <- fetch_uri(opts),
         {:ok, connection_config} <- parse_uri_and_opts(uri, opts) do
      pool_config =
        @default_pool_config
        |> Map.merge(Enum.into(Keyword.take(opts, [:pool_size, :max_overflow, :strategy]), %{}))

      pool_name = opts[:name] || __MODULE__

      poolboy_config = [
        name: {:local, pool_name},
        worker_module: Neo4j.Connection.Pool.Worker,
        size: pool_config.pool_size,
        max_overflow: pool_config.max_overflow,
        strategy: pool_config.strategy
      ]

      # Convert connection_config map to keyword list for poolboy
      worker_args = Map.to_list(connection_config)

      case :poolboy.start_link(poolboy_config, worker_args) do
        {:ok, _pid} -> {:ok, pool_name}
        {:error, {:already_started, _pid}} -> {:ok, pool_name}
        error -> error
      end
    end
  end

  @doc """
  Stop a connection pool.

  ## Parameters
  - `pool_name` - Pool name (default: #{__MODULE__})
  """
  def stop_pool(pool_name \\ __MODULE__) do
    :poolboy.stop(pool_name)
  end

  @doc """
  Get a connection from the pool.

  ## Parameters
  - `pool_name` - Pool name (default: #{__MODULE__})
  - `timeout` - Checkout timeout in milliseconds (default: 5000)

  ## Returns
  - Connection worker PID
  """
  def checkout(pool_name \\ __MODULE__, timeout \\ 5000) do
    :poolboy.checkout(pool_name, true, timeout)
  end

  @doc """
  Return a connection to the pool.

  ## Parameters
  - `pool_name` - Pool name (default: #{__MODULE__})
  - `worker` - Connection worker PID
  """
  def checkin(pool_name \\ __MODULE__, worker) do
    :poolboy.checkin(pool_name, worker)
  end

  @doc """
  Execute a query using a pooled connection.

  ## Parameters
  - `query` - Cypher query string
  - `params` - Query parameters map (default: %{})
  - `opts` - Query options (default: [])

  ## Options
  - `:pool_name` - Pool name (default: #{__MODULE__})
  - `:timeout` - Query timeout in milliseconds

  ## Returns
  - `{:ok, results}` on success
  - `{:error, reason}` on failure

  ## Examples

      {:ok, results} = Neo4j.Connection.Pool.run("MATCH (n:Person) RETURN n")
      {:ok, results} = Neo4j.Connection.Pool.run("CREATE (p:Person {name: $name})", %{name: "Alice"})
  """
  def run(query, params \\ %{}, opts \\ []) do
    pool_name = opts[:pool_name] || __MODULE__
    timeout = opts[:timeout] || 30_000

    :poolboy.transaction(
      pool_name,
      fn worker ->
        Neo4j.Connection.Pool.Worker.run(worker, query, params, opts)
      end,
      timeout
    )
  end

  @doc """
  Execute a function within a transaction using a pooled connection.

  ## Parameters
  - `fun` - Function to execute within the transaction
  - `opts` - Transaction options (default: [])

  ## Options
  - `:pool_name` - Pool name (default: #{__MODULE__})
  - `:timeout` - Transaction timeout in milliseconds

  ## Returns
  Result of the function

  ## Examples

      Neo4j.Connection.Pool.transaction(fn ->
        Neo4j.Connection.Pool.run("CREATE (p:Person {name: 'Alice'})")
        Neo4j.Connection.Pool.run("CREATE (p:Person {name: 'Bob'})")
      end)
  """
  def transaction(fun, opts \\ []) when is_function(fun, 0) do
    pool_name = opts[:pool_name] || __MODULE__
    timeout = opts[:timeout] || 30_000

    :poolboy.transaction(
      pool_name,
      fn worker ->
        Neo4j.Connection.Pool.Worker.transaction(worker, fun, opts)
      end,
      timeout
    )
  end

  @doc """
  Get pool status information.

  ## Parameters
  - `pool_name` - Pool name (default: #{__MODULE__})

  ## Returns
  Map with pool status information
  """
  def status(pool_name \\ __MODULE__) do
    case :poolboy.status(pool_name) do
      {:ready, size, overflow, workers} ->
        %{
          status: :ready,
          size: size,
          overflow: overflow,
          workers: workers
        }

      {:full, size, overflow, workers} ->
        %{
          status: :full,
          size: size,
          overflow: overflow,
          workers: workers
        }

      {:empty, size, overflow, workers} ->
        %{
          status: :empty,
          size: size,
          overflow: overflow,
          workers: workers
        }

      other ->
        other
    end
  end

  # Private Functions

  defp fetch_uri(opts) do
    case Keyword.fetch(opts, :uri) do
      {:ok, uri} -> {:ok, uri}
      :error -> {:error, {:missing_required_option, :uri}}
    end
  end

  defp parse_uri_and_opts(uri, opts) do
    case parse_uri(uri) do
      {:ok, uri_config} ->
        config =
          @default_connection_config
          |> Map.merge(uri_config)
          |> Map.merge(
            Enum.into(
              Keyword.take(opts, [:auth, :user_agent, :connection_timeout, :query_timeout]),
              %{}
            )
          )

        # Normalize auth
        config = %{config | auth: normalize_auth(config.auth)}
        {:ok, config}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_uri("bolt://" <> rest) do
    case String.split(rest, ":", parts: 2) do
      [host, port] ->
        case Integer.parse(port) do
          {port_int, ""} -> {:ok, %{host: host, port: port_int}}
          _ -> {:error, {:invalid_port, port}}
        end

      [host] ->
        {:ok, %{host: host}}
    end
  end

  defp parse_uri(uri) do
    {:error, {:unsupported_uri_scheme, uri}}
  end

  defp normalize_auth(nil), do: %{}

  defp normalize_auth({username, password}) do
    %{
      "scheme" => "basic",
      "principal" => username,
      "credentials" => password
    }
  end

  defp normalize_auth(auth) when is_map(auth), do: auth
end
