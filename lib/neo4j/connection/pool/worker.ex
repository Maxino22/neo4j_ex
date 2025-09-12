defmodule Neo4j.Connection.Pool.Worker do
  @moduledoc """
  Connection pool worker for Neo4j connections.

  This module implements a poolboy worker that manages individual Neo4j connections
  within the connection pool.
  """

  use GenServer
  require Logger

  alias Neo4j.Connection.{Socket, Handshake}
  alias Neo4j.Protocol.Messages
  alias Neo4j.{Session, Transaction}

  defstruct [:socket, :config, :connected]

  # Poolboy Worker API

  def start_link(connection_config) do
    GenServer.start_link(__MODULE__, connection_config)
  end

  @doc """
  Execute a query using this worker's connection.

  ## Parameters
  - `worker` - Worker PID
  - `query` - Cypher query string
  - `params` - Query parameters map
  - `opts` - Query options

  ## Returns
  - `{:ok, results}` on success
  - `{:error, reason}` on failure
  """
  def run(worker, query, params \\ %{}, opts \\ []) do
    GenServer.call(worker, {:run, query, params, opts}, opts[:timeout] || 30_000)
  end

  @doc """
  Execute a function within a transaction using this worker's connection.

  ## Parameters
  - `worker` - Worker PID
  - `fun` - Function to execute within the transaction
  - `opts` - Transaction options

  ## Returns
  Result of the function
  """
  def transaction(worker, fun, opts \\ []) when is_function(fun, 0) do
    GenServer.call(worker, {:transaction, fun, opts}, opts[:timeout] || 30_000)
  end

  @doc """
  Get connection status.

  ## Parameters
  - `worker` - Worker PID

  ## Returns
  - `:connected` if connection is healthy
  - `:disconnected` if connection is not available
  """
  def status(worker) do
    GenServer.call(worker, :status)
  end

  # GenServer Callbacks

  @impl true
  def init(connection_config) do
    Logger.debug("Starting Neo4j connection pool worker")

    # Convert keyword list to map for easier access
    config_map = Enum.into(connection_config, %{})

    state = %__MODULE__{
      socket: nil,
      config: config_map,
      connected: false
    }

    # Connect immediately
    case connect(state) do
      {:ok, new_state} ->
        {:ok, new_state}
      {:error, reason} ->
        Logger.error("Failed to establish initial connection: #{inspect(reason)}")
        # Start disconnected, will retry on first use
        {:ok, state}
    end
  end

  @impl true
  def handle_call({:run, query, params, opts}, _from, state) do
    case ensure_connected(state) do
      {:ok, connected_state} ->
        case execute_query(connected_state, query, params, opts) do
          {:ok, result} ->
            {:reply, {:ok, result}, connected_state}
          {:error, reason} ->
            Logger.warning("Query failed: #{inspect(reason)}")
            # Try to reconnect for next query
            new_state = %{connected_state | connected: false}
            {:reply, {:error, reason}, new_state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:transaction, fun, opts}, _from, state) do
    case ensure_connected(state) do
      {:ok, connected_state} ->
        case execute_transaction(connected_state, fun, opts) do
          {:ok, result} ->
            {:reply, {:ok, result}, connected_state}
          {:error, reason} ->
            Logger.warning("Transaction failed: #{inspect(reason)}")
            # Try to reconnect for next query
            new_state = %{connected_state | connected: false}
            {:reply, {:error, reason}, new_state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = if state.connected, do: :connected, else: :disconnected
    {:reply, status, state}
  end

  @impl true
  def terminate(_reason, state) do
    if state.socket do
      Socket.close(state.socket)
    end
    :ok
  end

  # Private Functions

  defp ensure_connected(%{connected: true} = state), do: {:ok, state}
  defp ensure_connected(state), do: connect(state)

  defp connect(state) do
    case create_connection(state.config) do
      {:ok, socket} ->
        new_state = %{state | socket: socket, connected: true}
        Logger.debug("Neo4j connection established")
        {:ok, new_state}

      {:error, reason} ->
        Logger.error("Failed to connect to Neo4j: #{inspect(reason)}")
        {:error, reason}
    end
  end

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

  defp execute_query(state, query, params, opts) do
    # Create a temporary session for this query
    session = %{
      socket: state.socket,
      config: state.config,
      transaction: nil
    }

    Session.run(session, query, params, opts)
  end

  defp execute_transaction(state, fun, _opts) do
    # Create a temporary session for this transaction
    session = %{
      socket: state.socket,
      config: state.config,
      transaction: nil
    }

    # The pool transaction function expects a 0-arity function,
    # but Neo4j.Transaction.execute expects a 1-arity function.
    # We need to wrap the 0-arity function to make it 1-arity.
    wrapped_fun = fn _tx ->
      fun.()
    end

    Transaction.execute(session, wrapped_fun)
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
