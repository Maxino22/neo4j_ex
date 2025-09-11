# Debug script to test Neo4j connection step by step

alias Neo4j.Connection.{Socket, Handshake}
alias Neo4j.Protocol.Messages

IO.puts("=== Neo4j Connection Debug ===")

# Step 1: Test TCP connection
IO.puts("1. Testing TCP connection...")
case Socket.connect("localhost", 7687, []) do
  {:ok, socket} ->
    IO.puts("   ✓ TCP connection successful")

    # Step 2: Test handshake
    IO.puts("2. Testing handshake...")
    case Handshake.perform(socket) do
      {:ok, version} ->
        IO.puts("   ✓ Handshake successful: Bolt v#{elem(version, 0)}.#{elem(version, 1)}")

        # Step 3: Test HELLO message
        IO.puts("3. Testing HELLO message...")
        auth = %{
          "scheme" => "basic",
          "principal" => "neo4j",
          "credentials" => "password"
        }

        hello_msg = Messages.hello("neo4j_ex/0.1.0", auth,
          bolt_agent: %{
            "product" => "neo4j_ex/0.1.0",
            "language" => "Elixir",
            "language_version" => System.version()
          }
        )

        IO.puts("   HELLO message: #{inspect(hello_msg)}")

        encoded = Messages.encode_message(hello_msg)
        IO.puts("   Encoded size: #{byte_size(encoded)} bytes")

        case Socket.send(socket, encoded) do
          :ok ->
            IO.puts("   ✓ HELLO message sent")

            # Step 4: Try to receive response with longer timeout
            IO.puts("4. Waiting for response (30s timeout)...")
            case Socket.recv(socket, timeout: 30_000) do
              {:ok, data} ->
                IO.puts("   ✓ Received #{byte_size(data)} bytes")
                IO.puts("   Raw data: #{Base.encode16(data)}")

                case Messages.decode_message(data) do
                  {:ok, message, _rest} ->
                    IO.puts("   ✓ Decoded message: #{inspect(message)}")

                    case Messages.parse_response(message) do
                      {:success, metadata} ->
                        IO.puts("   ✓ Authentication successful!")
                        IO.puts("   Server: #{metadata["server"] || "unknown"}")
                      {:failure, metadata} ->
                        IO.puts("   ✗ Authentication failed: #{metadata["message"]}")
                      other ->
                        IO.puts("   ? Unexpected response: #{inspect(other)}")
                    end

                  {:incomplete} ->
                    IO.puts("   ! Message incomplete, need more data")
                  {:error, reason} ->
                    IO.puts("   ✗ Decode error: #{inspect(reason)}")
                end

              {:error, reason} ->
                IO.puts("   ✗ Receive error: #{inspect(reason)}")
            end

          {:error, reason} ->
            IO.puts("   ✗ Send error: #{inspect(reason)}")
        end

      {:error, reason} ->
        IO.puts("   ✗ Handshake failed: #{inspect(reason)}")
    end

    Socket.close(socket)

  {:error, reason} ->
    IO.puts("   ✗ TCP connection failed: #{inspect(reason)}")
end

IO.puts("=== Debug Complete ===")
