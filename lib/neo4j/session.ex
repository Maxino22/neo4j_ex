defmodule Neo4j.Session do
  @moduledoc """
  Neo4j Session for executing queries and managing transactions.

  A session is a container for a sequence of transactions. Sessions borrow connections
  from the driver's connection pool and should be closed when no longer needed.

  ## Usage

      # Within a driver session block
      Neo4j.Driver.session(driver, fn session ->
        {:ok, result} = Neo4j.Session.run(session, "MATCH (n:Person) RETURN n.name")
        # Process result...
      end)

      # Manual session management
      {:ok, session} = Neo4j.Driver.create_session(driver)
      {:ok, result} = Neo4j.Session.run(session, "MATCH (n:Person) RETURN n.name")
      Neo4j.Session.close(session)
  """

  alias Neo4j.Connection.Socket
  alias Neo4j.Protocol.Messages
  alias Neo4j.Result.{Record, Summary}

  @doc """
  Executes a Cypher query in the session.

  ## Parameters
    - session: Session map
    - query: Cypher query string
    - params: Query parameters map (default: %{})
    - opts: Query options (default: [])

  ## Options
    - `:timeout` - Query timeout in milliseconds

  ## Returns
    - `{:ok, results}` on success where results is a list of records
    - `{:error, reason}` on failure

  ## Examples

      {:ok, results} = Neo4j.Session.run(session, "MATCH (n:Person) RETURN n.name")
      {:ok, results} = Neo4j.Session.run(session, "CREATE (p:Person {name: $name})", %{name: "Alice"})
  """
  def run(session, query, params \\ %{}, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, session.config.query_timeout)

    with :ok <- send_run_message(session, query, params),
         {:ok, run_response} <- receive_message(session.socket, timeout),
         {:success, _metadata} <- Messages.parse_response(run_response),
         :ok <- send_pull_message(session),
         {:ok, results} <- collect_results(session.socket, timeout) do
      {:ok, results}
    else
      {:failure, metadata} ->
        {:error, {:query_failed, metadata["message"]}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Begins a new transaction in the session.

  ## Parameters
    - session: Session map
    - opts: Transaction options (default: [])

  ## Options
    - `:mode` - Transaction mode ("r" for read, "w" for write)
    - `:timeout` - Transaction timeout in milliseconds

  ## Returns
    - `{:ok, transaction}` on success
    - `{:error, reason}` on failure

  ## Examples

      {:ok, tx} = Neo4j.Session.begin_transaction(session)
      {:ok, tx} = Neo4j.Session.begin_transaction(session, mode: "w", timeout: 30_000)
  """
  def begin_transaction(session, opts \\ []) do
    metadata = build_transaction_metadata(opts)
    timeout = Keyword.get(opts, :timeout, session.config.query_timeout)

    begin_msg = Messages.begin_tx(metadata)

    with :ok <- Socket.send(session.socket, Messages.encode_message(begin_msg)),
         {:ok, response} <- receive_message(session.socket, timeout),
         {:success, _metadata} <- Messages.parse_response(response) do
      transaction = %{
        session: session,
        socket: session.socket,
        config: session.config,
        metadata: metadata
      }
      {:ok, transaction}
    else
      {:failure, metadata} ->
        {:error, {:transaction_failed, metadata["message"]}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Closes the session and releases its connection.

  ## Parameters
    - session: Session to close

  ## Examples

      Neo4j.Session.close(session)
  """
  def close(session) do
    # Send GOODBYE message
    goodbye_msg = Messages.goodbye()
    Socket.send(session.socket, Messages.encode_message(goodbye_msg))

    # Close the socket
    Socket.close(session.socket)
    :ok
  end

  @doc """
  Gets session information.

  ## Parameters
    - session: Session map

  ## Returns
    Session information map
  """
  def info(session) do
    %{
      config: session.config,
      transaction: session.transaction
    }
  end

  # Private Functions

  defp send_run_message(session, query, params) do
    run_msg = Messages.run(query, params, %{})
    Socket.send(session.socket, Messages.encode_message(run_msg))
  end

  defp send_pull_message(session) do
    pull_msg = Messages.pull(%{"n" => -1})  # Pull all records
    Socket.send(session.socket, Messages.encode_message(pull_msg))
  end

  defp collect_results(socket, timeout, acc \\ []) do
    case receive_message(socket, timeout) do
      {:ok, response} ->
        case Messages.parse_response(response) do
          {:record, values} ->
            record = Record.new(values)
            collect_results(socket, timeout, [record | acc])

          {:success, metadata} ->
            summary = Summary.new(metadata)
            results = %{
              records: Enum.reverse(acc),
              summary: summary
            }
            {:ok, results}

          {:failure, metadata} ->
            {:error, {:query_execution_failed, metadata["message"]}}

          other ->
            {:error, {:unexpected_response, other}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp receive_message(socket, timeout, buffer \\ <<>>) do
    case Socket.recv(socket, timeout: timeout) do
      {:ok, data} ->
        full_data = <<buffer::binary, data::binary>>

        case Messages.decode_message(full_data) do
          {:ok, message, _rest} ->
            {:ok, message}
          {:incomplete} ->
            receive_message(socket, timeout, full_data)
          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_transaction_metadata(opts) do
    metadata = %{}

    metadata =
      case Keyword.get(opts, :mode) do
        nil -> metadata
        mode -> Map.put(metadata, "mode", mode)
      end

    metadata =
      case Keyword.get(opts, :timeout) do
        nil -> metadata
        timeout -> Map.put(metadata, "tx_timeout", timeout)
      end

    metadata
  end
end
