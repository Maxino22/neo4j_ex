defmodule Neo4j.Connection.Handshake do
  @moduledoc """
  Implements the Bolt protocol handshake for version negotiation.
  Supports Bolt v5.1+ (no backwards compatibility with older versions).
  """

  alias Neo4j.Connection.Socket

  # Bolt magic preamble - identifies this as Bolt protocol
  @bolt_magic <<0x60, 0x60, 0xB0, 0x17>>

  # Supported Bolt versions (v5.4, v5.3, v5.2, v5.1)
  # Format: [minor, 0, 0, major] for each version
  @bolt_versions [
    {5, 4},
    {5, 3},
    {5, 2},
    {5, 1}
  ]

  @doc """
  Performs the Bolt handshake on an established socket connection.

  Returns the negotiated version or an error if handshake fails.

  ## Example
      {:ok, socket} = Socket.connect("localhost", 7687)
      {:ok, {5, 4}} = Handshake.perform(socket)
  """
  def perform(socket) do
    with :ok <- send_handshake(socket),
         {:ok, version} <- receive_version(socket) do
      {:ok, version}
    end
  end

  @doc """
  Sends the handshake request: magic preamble + version proposals.
  """
  def send_handshake(socket) do
    handshake_data = build_handshake_data()
    Socket.send(socket, handshake_data)
  end

  @doc """
  Receives and parses the server's version response.
  """
  def receive_version(socket) do
    case Socket.recv(socket, length: 4) do
      {:ok, <<0, 0, 0, 0>>} ->
        {:error, :version_negotiation_failed}

      {:ok, version_bytes} ->
        parse_version(version_bytes)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Builds the complete handshake data packet.
  """
  def build_handshake_data do
    version_bytes = Enum.map(@bolt_versions, &encode_version/1)

    # Pad with zeros if we have less than 4 versions
    padding = List.duplicate(<<0, 0, 0, 0>>, 4 - length(version_bytes))

    [@bolt_magic | version_bytes ++ padding]
    |> IO.iodata_to_binary()
  end

  @doc """
  Encodes a version tuple into 4 bytes.

  ## Format
  For Bolt v5+: [minor, 0, 0, major]
  """
  def encode_version({major, minor}) do
    <<minor::8, 0::8, 0::8, major::8>>
  end

  @doc """
  Parses version bytes from server response.
  """
  def parse_version(<<minor::8, 0::8, 0::8, major::8>>) do
    {:ok, {major, minor}}
  end

  def parse_version(<<0, 0, minor::8, major::8>>) do
    # Handle alternative Bolt v5+ format (used by Memgraph and some other servers)
    {:ok, {major, minor}}
  end

  def parse_version(_) do
    {:error, :invalid_version_format}
  end

  @doc """
  Checks if a version is supported by this driver.
  """
  def supported_version?({major, minor}) do
    {major, minor} in @bolt_versions
  end

  @doc """
  Returns list of supported versions.
  """
  def supported_versions do
    @bolt_versions
  end
end
