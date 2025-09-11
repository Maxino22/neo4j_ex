defmodule Neo4j.Transaction do
  @moduledoc """
  Neo4j Transaction for executing queries within a transactional context.

  Transactions provide ACID guarantees and allow you to group multiple queries
  together. They can be committed or rolled back as a unit.

  ## Usage

      # Using driver transaction helper
      result = Neo4j.Driver.transaction(driver, fn tx ->
        Neo4j.Transaction.run(tx, "CREATE (p:Person {name: $name})", %{name: "Alice"})
        Neo4j.Transaction.run(tx, "CREATE (p:Person {name: $name})", %{name: "Bob"})
        # Transaction is automatically committed if function succeeds
      end)

      # Manual transaction management
      {:ok, session} = Neo4j.Driver.create_session(driver)
      {:ok, tx} = Neo4j.Session.begin_transaction(session)
      {:ok, result} = Neo4j.Transaction.run(tx, "CREATE (p:Person {name: $name})", %{name: "Carol"})
      :ok = Neo4j.Transaction.commit(tx)
      Neo4j.Session.close(session)
  """

  alias Neo4j.Connection.Socket
  alias Neo4j.Protocol.Messages
  alias Neo4j.Result.{Record, Summary}

  @doc """
  Executes a function within a transaction context.

  The transaction is automatically committed if the function succeeds,
  or rolled back if it raises an exception.

  ## Parameters
    - session: Session to create transaction in
    - fun: Function that receives the transaction as an argument

  ## Returns
    - Result of the function on success
    - `{:error, reason}` on failure

  ## Examples

      result = Neo4j.Transaction.execute(session, fn tx ->
        Neo4j.Transaction.run(tx, "CREATE (p:Person {name: $name})", %{name: "Alice"})
        Neo4j.Transaction.run(tx, "MATCH (p:Person) RETURN count(p)")
      end)
  """
  def execute(session, fun) when is_function(fun, 1) do
    with {:ok, tx} <- Neo4j.Session.begin_transaction(session) do
      try do
        result = fun.(tx)
        case commit(tx) do
          :ok -> {:ok, result}
          {:error, reason} -> {:error, reason}
        end
      rescue
        error ->
          rollback(tx)
          reraise error, __STACKTRACE__
      catch
        :throw, value ->
          rollback(tx)
          throw(value)
        :exit, reason ->
          rollback(tx)
          exit(reason)
      end
    end
  end

  @doc """
  Executes a Cypher query within the transaction.

  ## Parameters
    - transaction: Transaction map
    - query: Cypher query string
    - params: Query parameters map (default: %{})
    - opts: Query options (default: [])

  ## Options
    - `:timeout` - Query timeout in milliseconds

  ## Returns
    - `{:ok, results}` on success where results is a list of records
    - `{:error, reason}` on failure

  ## Examples

      {:ok, results} = Neo4j.Transaction.run(tx, "MATCH (n:Person) RETURN n.name")
      {:ok, results} = Neo4j.Transaction.run(tx, "CREATE (p:Person {name: $name})", %{name: "Alice"})
  """
  def run(transaction, query, params \\ %{}, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, transaction.config.query_timeout)

    with :ok <- send_run_message(transaction, query, params),
         {:ok, run_response} <- receive_message(transaction.socket, timeout),
         {:success, _metadata} <- Messages.parse_response(run_response),
         :ok <- send_pull_message(transaction),
         {:ok, results} <- collect_results(transaction.socket, timeout) do
      {:ok, results}
    else
      {:failure, metadata} ->
        {:error, {:query_failed, metadata["message"]}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Commits the transaction.

  ## Parameters
    - transaction: Transaction to commit

  ## Returns
    - `:ok` on success
    - `{:error, reason}` on failure

  ## Examples

      :ok = Neo4j.Transaction.commit(tx)
  """
  def commit(transaction) do
    timeout = transaction.config.query_timeout
    commit_msg = Messages.commit()

    with :ok <- Socket.send(transaction.socket, Messages.encode_message(commit_msg)),
         {:ok, response} <- receive_message(transaction.socket, timeout),
         {:success, _metadata} <- Messages.parse_response(response) do
      :ok
    else
      {:failure, metadata} ->
        {:error, {:commit_failed, metadata["message"]}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Rolls back the transaction.

  ## Parameters
    - transaction: Transaction to rollback

  ## Returns
    - `:ok` on success
    - `{:error, reason}` on failure

  ## Examples

      :ok = Neo4j.Transaction.rollback(tx)
  """
  def rollback(transaction) do
    timeout = transaction.config.query_timeout
    rollback_msg = Messages.rollback()

    with :ok <- Socket.send(transaction.socket, Messages.encode_message(rollback_msg)),
         {:ok, response} <- receive_message(transaction.socket, timeout),
         {:success, _metadata} <- Messages.parse_response(response) do
      :ok
    else
      {:failure, metadata} ->
        {:error, {:rollback_failed, metadata["message"]}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets transaction information.

  ## Parameters
    - transaction: Transaction map

  ## Returns
    Transaction information map
  """
  def info(transaction) do
    %{
      session: transaction.session,
      metadata: transaction.metadata
    }
  end

  # Private Functions

  defp send_run_message(transaction, query, params) do
    run_msg = Messages.run(query, params, %{})
    Socket.send(transaction.socket, Messages.encode_message(run_msg))
  end

  defp send_pull_message(transaction) do
    pull_msg = Messages.pull(%{"n" => -1})  # Pull all records
    Socket.send(transaction.socket, Messages.encode_message(pull_msg))
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
end