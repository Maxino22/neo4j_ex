defmodule Neo4j.Protocol.Messages do
  @moduledoc """
  Bolt protocol message definitions and encoding/decoding.

  Supports Bolt v5+ messages for authentication and query execution.
  """

  require Logger
  alias Neo4j.Protocol.PackStream

  # Message signatures (Bolt v5+)
  @hello_signature 0x01
  @logon_signature 0x6A
  @logoff_signature 0x6B
  @goodbye_signature 0x02
  @reset_signature 0x0F
  @run_signature 0x10
  @discard_signature 0x2F
  @pull_signature 0x3F
  @begin_signature 0x11
  @commit_signature 0x12
  @rollback_signature 0x13
  @route_signature 0x66

  # Response signatures
  @success_signature 0x70
  @failure_signature 0x7F
  @ignored_signature 0x7E
  @record_signature 0x71

  # ============================================================================
  # Request Messages
  # ============================================================================

  @doc """
  Creates a HELLO message for initial authentication (Bolt v5+).

  ## Parameters
    - user_agent: Client identification string
    - auth: Authentication map (can be empty for no auth)
    - routing: Optional routing context
    - bolt_agent: Optional detailed agent info
  """
  def hello(user_agent, auth \\ %{}, opts \\ []) do
    extra = %{
      "user_agent" => user_agent
    }

    extra =
      if routing = opts[:routing] do
        Map.put(extra, "routing", routing)
      else
        extra
      end

    extra =
      if bolt_agent = opts[:bolt_agent] do
        Map.put(extra, "bolt_agent", bolt_agent)
      else
        extra
      end

    # Merge auth into extra for HELLO
    extra = Map.merge(extra, auth)

    {:struct, @hello_signature, [extra]}
  end

  @doc """
  Creates a LOGON message for authentication (Bolt v5.1+).

  ## Parameters
    - scheme: Authentication scheme ("none", "basic", "bearer")
    - auth: Authentication credentials map
  """
  def logon(scheme, auth \\ %{}) do
    auth_map = Map.put(auth, "scheme", scheme)
    {:struct, @logon_signature, [auth_map]}
  end

  @doc """
  Creates a LOGOFF message to clear authentication state.
  """
  def logoff do
    {:struct, @logoff_signature, []}
  end

  @doc """
  Creates a GOODBYE message for graceful disconnect.
  """
  def goodbye do
    {:struct, @goodbye_signature, []}
  end

  @doc """
  Creates a RESET message to reset the connection state.
  """
  def reset do
    {:struct, @reset_signature, []}
  end

  @doc """
  Creates a RUN message to execute a Cypher query.

  ## Parameters
    - query: Cypher query string
    - params: Query parameters map
    - metadata: Optional metadata map
  """
  def run(query, params \\ %{}, metadata \\ %{}) do
    {:struct, @run_signature, [query, params, metadata]}
  end

  @doc """
  Creates a DISCARD message to discard remaining records.

  ## Parameters
    - metadata: Optional metadata (n: number to discard, qid: query id)
  """
  def discard(metadata \\ %{}) do
    {:struct, @discard_signature, [metadata]}
  end

  @doc """
  Creates a PULL message to fetch records.

  ## Parameters
    - metadata: Optional metadata (n: number to pull, qid: query id)
  """
  def pull(metadata \\ %{}) do
    {:struct, @pull_signature, [metadata]}
  end

  @doc """
  Creates a BEGIN message to start a transaction.

  ## Parameters
    - metadata: Transaction metadata (mode, bookmarks, tx_timeout, etc.)
  """
  def begin_tx(metadata \\ %{}) do
    {:struct, @begin_signature, [metadata]}
  end

  @doc """
  Creates a COMMIT message to commit the current transaction.
  """
  def commit do
    {:struct, @commit_signature, []}
  end

  @doc """
  Creates a ROLLBACK message to rollback the current transaction.
  """
  def rollback do
    {:struct, @rollback_signature, []}
  end

  @doc """
  Creates a ROUTE message for cluster routing information.

  ## Parameters
    - routing: Routing context map
    - bookmarks: List of bookmarks
    - db: Database name (nil for default)
  """
  def route(routing \\ %{}, bookmarks \\ [], db \\ nil) do
    metadata = %{
      "routing" => routing,
      "bookmarks" => bookmarks
    }

    metadata =
      if db do
        Map.put(metadata, "db", db)
      else
        metadata
      end

    {:struct, @route_signature, [metadata]}
  end

  # ============================================================================
  # Response Parsing
  # ============================================================================

  @doc """
  Parses a response message structure.
  """
  def parse_response({:struct, @success_signature, [metadata]}) do
    {:success, metadata}
  end

  def parse_response({:struct, @failure_signature, [metadata]}) do
    {:failure, metadata}
  end

  def parse_response({:struct, @ignored_signature, []}) do
    {:ignored, %{}}
  end

  def parse_response({:struct, @ignored_signature, [metadata]}) do
    {:ignored, metadata}
  end

  def parse_response({:struct, @record_signature, [values]}) when is_list(values) do
    {:record, values}
  end

  def parse_response({:struct, signature, fields}) do
    {:unknown, signature, fields}
  end

  def parse_response(other) do
    {:error, {:invalid_response, other}}
  end

  # ============================================================================
  # Message Encoding/Decoding with Chunking
  # ============================================================================

  @doc """
  Encodes a message with chunking for transmission.

  Messages are split into chunks with 2-byte headers.
  Maximum chunk size is 65535 bytes.
  Message ends with 0x0000.
  """
  def encode_message(message) do
    encoded = PackStream.encode(message)
    chunk_message(encoded)
  end

  @doc """
  Chunks a message for Bolt protocol transmission.
  """
  def chunk_message(data, acc \\ [])

  def chunk_message(<<>>, acc) do
    # Add end-of-message marker
    IO.iodata_to_binary(Enum.reverse([<<0x00, 0x00>> | acc]))
  end

  def chunk_message(data, acc) when byte_size(data) <= 65535 do
    size = byte_size(data)
    chunk = <<size::16, data::binary>>
    chunk_message(<<>>, [chunk | acc])
  end

  def chunk_message(data, acc) do
    <<chunk::binary-size(65535), rest::binary>> = data
    header = <<65535::16>>
    chunk_message(rest, [<<header::binary, chunk::binary>> | acc])
  end

  @doc """
  Decodes a chunked message from received data.

  Returns {:ok, message, remaining_data} or {:error, reason} or {:incomplete}.
  """
  def decode_message(data, buffer \\ <<>>)

  def decode_message(<<0x00, 0x00, rest::binary>>, buffer) when buffer != <<>> do
    # End of message marker found

    case PackStream.decode(buffer) do
      {:ok, message, <<>>} ->
        {:ok, message, rest}

      {:ok, _message, _leftover} ->
        {:error, :invalid_message_format}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def decode_message(<<size::16, rest::binary>>, buffer) when size > 0 do
    if byte_size(rest) >= size do
      <<chunk::binary-size(size), remaining::binary>> = rest
      decode_message(remaining, <<buffer::binary, chunk::binary>>)
    else
      {:incomplete}
    end
  end

  def decode_message(<<0x00, 0x00, _rest::binary>>, <<>>) do
    # Empty message
    Logger.warning("Messages: empty message received")
    {:error, :empty_message}
  end

  def decode_message(data, _buffer) when byte_size(data) < 2 do
    {:incomplete}
  end

  def decode_message(_, _) do
    {:incomplete}
  end

  @doc """
  Decodes multiple messages from a buffer.
  """
  def decode_messages(data, acc \\ [])

  def decode_messages(<<>>, acc) do
    {:ok, Enum.reverse(acc), <<>>}
  end

  def decode_messages(data, acc) do
    case decode_message(data) do
      {:ok, message, rest} ->
        decode_messages(rest, [message | acc])

      {:incomplete} ->
        {:ok, Enum.reverse(acc), data}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ============================================================================
  # Utility Functions
  # ============================================================================

  @doc """
  Returns the name of a message signature.
  """
  def signature_name(@hello_signature), do: "HELLO"
  def signature_name(@logon_signature), do: "LOGON"
  def signature_name(@logoff_signature), do: "LOGOFF"
  def signature_name(@goodbye_signature), do: "GOODBYE"
  def signature_name(@reset_signature), do: "RESET"
  def signature_name(@run_signature), do: "RUN"
  def signature_name(@discard_signature), do: "DISCARD"
  def signature_name(@pull_signature), do: "PULL"
  def signature_name(@begin_signature), do: "BEGIN"
  def signature_name(@commit_signature), do: "COMMIT"
  def signature_name(@rollback_signature), do: "ROLLBACK"
  def signature_name(@route_signature), do: "ROUTE"
  def signature_name(@success_signature), do: "SUCCESS"
  def signature_name(@failure_signature), do: "FAILURE"
  def signature_name(@ignored_signature), do: "IGNORED"
  def signature_name(@record_signature), do: "RECORD"
  def signature_name(sig), do: "UNKNOWN(0x#{Integer.to_string(sig, 16)})"

  @doc """
  Checks if a message is a summary message (SUCCESS or FAILURE).
  """
  def summary_message?({:struct, sig, _}) when sig in [@success_signature, @failure_signature] do
    true
  end

  def summary_message?(_), do: false
end
