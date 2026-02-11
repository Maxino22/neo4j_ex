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

  alias Neo4j.Result.Summary
  alias Neo4j.Connection.Socket
  alias Neo4j.Protocol.Messages
  alias Neo4j.Result.Record

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
  def run(session, query, params, opts) do
    timeout = Keyword.get(opts, :timeout, session.config.query_timeout)

    # Clear any existing buffer for this socket
    :erlang.erase({:message_buffer, session.socket})

    # Send RUN message
    run_msg = Messages.run(query, params, %{})
    encoded_run = Messages.encode_message(run_msg)

    with :ok <- Socket.send(session.socket, encoded_run),
         {:ok, run_response} <- receive_message(session.socket, timeout),
         {:success, metadata} <- Messages.parse_response(run_response) do

      # Send PULL message
      fields = Map.get(metadata, "fields", [])
      pull_msg = Messages.pull(%{"n" => -1})
      encoded_pull = Messages.encode_message(pull_msg)

      with :ok <- Socket.send(session.socket, encoded_pull),
           {:ok, results} <- collect_results(session.socket, timeout, fields) do
        # Clear the buffer when done
        :erlang.erase({:message_buffer, session.socket})
        # Return results in the expected format
        {:ok, results }
      else
        {:error, reason} ->
          # Clear the buffer on error
          :erlang.erase({:message_buffer, session.socket})
          {:error, reason}
      end
    else
      {:failure, metadata} ->
        # Clear the buffer on failure
        :erlang.erase({:message_buffer, session.socket})
        {:error, {:query_failed, metadata["message"]}}
      {:error, reason} ->
        # Clear the buffer on error
        :erlang.erase({:message_buffer, session.socket})
        {:error, reason}
    end
  end

  def run(session, query) do
    run(session, query, %{}, [])
  end

  def run(session, query, params) do
    run(session, query, params, [])
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
  def begin_transaction(session, opts) do
    # Clear any existing buffer for this socket
    :erlang.erase({:message_buffer, session.socket})

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

  def begin_transaction(session) do
    begin_transaction(session, [])
  end

  @doc """
  Closes the session and releases its connection.

  ## Parameters
    - session: Session to close

  ## Examples

      Neo4j.Session.close(session)
  """
  def close(session) do
    # Clear any existing buffer for this socket
    :erlang.erase({:message_buffer, session.socket})

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

  defp collect_results(socket, timeout, fields) do
    collect_results(socket, timeout, fields, [])
  end

  defp collect_results(socket, timeout, fields, acc) do
    case receive_message(socket, timeout) do
      {:ok, response} ->
        case Messages.parse_response(response) do
          {:record, values} ->
            # Create a Record struct
            record = Record.new(values, fields)
            collect_results(socket, timeout, fields, [record | acc])

          {:success, metadata} ->
            summary = Summary.new(metadata)

            results = %{
              records: Enum.reverse(acc),
              summary: summary
            }

            # Return just the list of record structs
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
    # Get any buffered data for this socket
    buffered_data = case :erlang.get({:message_buffer, socket}) do
      :undefined -> <<>>
      data -> data
    end

    # Combine any buffered data with the new buffer
    combined_buffer = <<buffered_data::binary, buffer::binary>>

    # Try to decode a message from the combined buffer
    case Messages.decode_message(combined_buffer) do
      {:ok, message, remaining} ->
        # We successfully decoded a message
        # Store any remaining data for next time
        if byte_size(remaining) > 0 do
          :erlang.put({:message_buffer, socket}, remaining)
        else
          :erlang.erase({:message_buffer, socket})
        end
        {:ok, message}

      {:incomplete} ->
        # Not enough data to decode a message, read from socket
        case Socket.recv(socket, timeout: timeout) do
          {:ok, data} ->
            full_data = <<combined_buffer::binary, data::binary>>

            # Try to decode again with the new data
            case Messages.decode_message(full_data) do
              {:ok, message, remaining} ->
                # We successfully decoded a message
                # Store any remaining data for next time
                if byte_size(remaining) > 0 do
                  :erlang.put({:message_buffer, socket}, remaining)
                else
                  :erlang.erase({:message_buffer, socket})
                end
                {:ok, message}

              {:incomplete} ->
                # Still not enough data, store what we have and recurse
                :erlang.put({:message_buffer, socket}, full_data)
                receive_message(socket, timeout, <<>>)

              {:error, reason} ->
                # Error decoding message
                :erlang.erase({:message_buffer, socket})
                {:error, reason}
            end

          {:error, reason} ->
            # Error reading from socket
            :erlang.erase({:message_buffer, socket})
            {:error, reason}
        end

      {:error, reason} ->
        # Error decoding message
        :erlang.erase({:message_buffer, socket})
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
