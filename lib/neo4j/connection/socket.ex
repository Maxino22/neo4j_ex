defmodule Neo4j.Connection.Socket do
  @moduledoc """
  Low-level TCP socket operations for Bolt protocol connections.
  Handles raw TCP communication with Neo4j/Memgraph servers.
  """

  @default_timeout 15_000
  @tcp_opts [:binary, {:packet, :raw}, {:active, false}, {:nodelay, true}]

  @doc """
  Opens a TCP connection to the specified host and port.

  ## Options
    * `:timeout` - Connection timeout in milliseconds (default: 15000)
    * `:tcp_opts` - Additional TCP options
  """
  def connect(host, port, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    additional_opts = Keyword.get(opts, :tcp_opts, [])

    tcp_opts = @tcp_opts ++ additional_opts

    host_charlist = host_to_charlist(host)

    case :gen_tcp.connect(host_charlist, port, tcp_opts, timeout) do
      {:ok, socket} ->
        {:ok, socket}
      {:error, reason} ->
        {:error, {:connection_failed, reason}}
    end
  end

  @doc """
  Sends binary data through the socket.
  """
  def send(socket, data) when is_binary(data) do
    case :gen_tcp.send(socket, data) do
      :ok -> :ok
      {:error, reason} -> {:error, {:send_failed, reason}}
    end
  end

  @doc """
  Receives data from the socket.

  ## Options
    * `:timeout` - Receive timeout in milliseconds (default: 15000)
    * `:length` - Number of bytes to receive (0 means all available)
  """
  def recv(socket, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    length = Keyword.get(opts, :length, 0)

    case :gen_tcp.recv(socket, length, timeout) do
      {:ok, data} ->
        {:ok, data}
      {:error, reason} ->
        {:error, {:recv_failed, reason}}
    end
  end

  @doc """
  Closes the TCP socket.
  """
  def close(socket) do
    :gen_tcp.close(socket)
  end

  @doc """
  Sets socket options.
  """
  def setopts(socket, opts) do
    :inet.setopts(socket, opts)
  end

  @doc """
  Gets socket options.
  """
  def getopts(socket, opts) do
    :inet.getopts(socket, opts)
  end

  # Helper function to convert string to charlist
  defp host_to_charlist(host) when is_binary(host), do: String.to_charlist(host)
  defp host_to_charlist(host) when is_list(host), do: host
  defp host_to_charlist(host) when is_atom(host), do: Atom.to_charlist(host)
end
