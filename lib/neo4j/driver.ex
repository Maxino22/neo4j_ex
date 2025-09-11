defmodule Neo4j.Driver do
  @moduledoc """
  Neo4j Driver for Elixir.

  This module provides the main interface for connecting to and interacting with Neo4j databases.
  It handles connection management, authentication, and provides a high-level API for executing queries.

  ## Usage

      # Connect to Neo4j
      {:ok, driver} = Neo4j.Driver.start_link("bolt://localhost:7687",
        auth: {"neo4j", "password"})

      # Simple query
      {:ok, results} = Neo4j.Driver.run(driver, "MATCH (n:Person) RETURN n.name", %{})

      # With session
      Neo4j.Driver.session(driver, fn session ->
        Neo4j.Session.run(session, "CREATE (p:Person {name: $name})", %{name: "Alice"})
      end)

      # Transaction
      Neo4j.Driver.transaction(driver, fn tx ->
        Neo4j.Transaction.run(tx, "CREATE (p:Person {name: $name})", %{name: "Bob"})
        Neo4j.Transaction.commit(tx)
      end)
  """

  use GenServer
  require Logger

  alias Neo4j.Connection.{Socket, Handshake}
  alias Neo4j.Protocol.Messages
  alias Neo4j.{Session, Transaction}

  @default_config %{
    host: "localhost",
    port: 7687,
    auth: nil,
    user_agent: "neo4j_ex/0.1.0",
    max_pool_size: 10,
    connection_timeout: 15_000,
    query_timeout: 30_000
  }

  # Client API

  @doc """
  Starts a new Neo4j driver.

  ## Parameters
    - uri: Connection URI (e.g., "bolt://localhost:7687")
    - opts: Configuration options

  ## Options
    - `:auth` - Authentication tuple `{username, password}` or map
    - `:user_agent` - Client user agent string
    - `:max_pool_size` - Maximum number of connections in pool
    - `:connection_timeout` - Connection timeout in milliseconds
    - `:query_timeout` - Query timeout in milliseconds

  ## Examples

      {:ok, driver} = Neo4j.Driver.start_link("bolt://localhost:7687",
        auth: {"neo4j", "password"})

      {:ok, driver} = Neo4j.Driver.start_link("bolt://localhost:7687",
        auth: %{"scheme" => "basic", "principal" => "neo4j", "credentials" => "password"})
  """
  def start_link(uri, opts \\ []) do
    config = parse_uri_and_opts(uri, opts)
    GenServer.start_link(__MODULE__, config, name: opts[:name])
  end

  @doc """
  Executes a Cypher query directly using the driver.

  This is a convenience method that creates a session, runs the query, and closes the session.

  ## Parameters
    - driver: Driver process
    - query: Cypher query string
    - params: Query parameters map (default: %{})
    - opts: Query options (default: [])

  ## Examples

      {:ok, results} = Neo4j.Driver.run(driver, "MATCH (n:Person) RETURN n.name", %{})
      {:ok, results} = Neo4j.Driver.run(driver, "CREATE (p:Person {name: $name})", %{name: "Alice"})
  """
  def run(driver, query, params \\ %{}, opts \\ []) do
    session(driver, fn session ->
      Session.run(session, query, params, opts)
    end)
  end

  @doc """
  Creates a session and executes the given function with it.

  The session is automatically closed after the function completes.

  ## Parameters
    - driver: Driver process
    - fun: Function that receives the session as an argument

  ## Examples

      result = Neo4j.Driver.session(driver, fn session ->
        Neo4j.Session.run(session, "MATCH (n:Person) RETURN count(n)")
      end)
  """
  def session(driver, fun) when is_function(fun, 1) do
    with {:ok, session} <- create_session(driver) do
      try do
        fun.(session)
      after
        close_session(session)
      end
    end
  end

  @doc """
  Creates a transaction and executes the given function with it.

  The transaction is automatically committed if the function succeeds,
  or rolled back if it raises an exception.

  ## Parameters
    - driver: Driver process
    - fun: Function that receives the transaction as an argument

  ## Examples

      result = Neo4j.Driver.transaction(driver, fn tx ->
        Neo4j.Transaction.run(tx, "CREATE (p:Person {name: $name})", %{name: "Bob"})
        Neo4j.Transaction.run(tx, "CREATE (p:Person {name: $name})", %{name: "Carol"})
      end)
  """
  def transaction(driver, fun) when is_function(fun, 1) do
    session(driver, fn session ->
      Transaction.execute(session, fun)
    end)
  end

  @doc """
  Creates a new session.

  Sessions should be closed when no longer needed using `close_session/1`.

  ## Parameters
    - driver: Driver process

  ## Returns
    - `{:ok, session}` on success
    - `{:error, reason}` on failure
  """
  def create_session(driver) do
    GenServer.call(driver, :create_session)
  end

  @doc """
  Closes a session.

  ## Parameters
    - session: Session to close
  """
  def close_session(session) do
    Session.close(session)
  end

  @doc """
  Closes the driver and all its connections.

  ## Parameters
    - driver: Driver process
  """
  def close(driver) do
    GenServer.call(driver, :close)
  end

  @doc """
  Gets driver configuration.

  ## Parameters
    - driver: Driver process

  ## Returns
    Current driver configuration map
  """
  def get_config(driver) do
    GenServer.call(driver, :get_config)
  end

  # GenServer Callbacks

  @impl true
  def init(config) do
    Logger.info("Starting Neo4j driver: #{config.host}:#{config.port}")

    state = %{
      config: config,
      connections: [],
      sessions: []
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:create_session, _from, state) do
    case create_connection(state.config) do
      {:ok, socket} ->
        session = %{
          socket: socket,
          config: state.config,
          transaction: nil
        }

        new_state = %{state | sessions: [session | state.sessions]}
        {:reply, {:ok, session}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:close, _from, state) do
    # Close all connections
    for connection <- state.connections do
      Socket.close(connection)
    end

    # Close all sessions
    for session <- state.sessions do
      Socket.close(session.socket)
    end

    {:reply, :ok, %{state | connections: [], sessions: []}}
  end

  @impl true
  def handle_call(:get_config, _from, state) do
    {:reply, state.config, state}
  end

  @impl true
  def terminate(_reason, state) do
    # Clean up connections
    for connection <- state.connections do
      Socket.close(connection)
    end

    for session <- state.sessions do
      Socket.close(session.socket)
    end

    :ok
  end

  # Private Functions

  defp parse_uri_and_opts(uri, opts) do
    config =
      @default_config
      |> Map.merge(parse_uri(uri))
      |> Map.merge(Enum.into(opts, %{}))

    # Normalize auth
    config = %{config | auth: normalize_auth(config.auth)}

    config
  end

  defp parse_uri("bolt://" <> rest) do
    case String.split(rest, ":", parts: 2) do
      [host, port] ->
        %{host: host, port: String.to_integer(port)}
      [host] ->
        %{host: host}
    end
  end

  defp parse_uri(uri) do
    raise ArgumentError, "Unsupported URI scheme. Expected bolt://. Got: #{uri}"
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

  defp create_connection(config) do
    with {:ok, socket} <- Socket.connect(config.host, config.port, timeout: config.connection_timeout),
         {:ok, _version} <- Handshake.perform(socket),
         :ok <- authenticate(socket, config) do
      {:ok, socket}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp authenticate(socket, config) do
    hello_msg = Messages.hello(config.user_agent, config.auth,
      bolt_agent: %{
        "product" => config.user_agent,
        "language" => "Elixir",
        "language_version" => System.version()
      }
    )

    with :ok <- Socket.send(socket, Messages.encode_message(hello_msg)),
         {:ok, response} <- receive_message(socket),
         {:success, _metadata} <- Messages.parse_response(response) do
      :ok
    else
      {:failure, metadata} ->
        {:error, {:auth_failed, metadata["message"]}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp receive_message(socket, buffer \\ <<>>, timeout \\ 15000) do
    case Socket.recv(socket, timeout: timeout) do
      {:ok, data} ->
        full_data = <<buffer::binary, data::binary>>

        case Messages.decode_message(full_data) do
          {:ok, message, _rest} ->
            {:ok, message}
          {:incomplete} ->
            receive_message(socket, full_data, timeout)
          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
