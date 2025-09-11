#!/usr/bin/env elixir

# Simple connection test script for Neo4j
# Usage: elixir scripts/test_connection.exs
# Or with custom credentials: NEO4J_USER=myuser NEO4J_PASS=mypass elixir scripts/test_connection.exs

Mix.install([
  {:neo4j_ex, path: "."}
])

defmodule ConnectionTest do
  def run do
    # Get configuration from environment or use defaults
    host = System.get_env("NEO4J_HOST", "localhost")
    port = System.get_env("NEO4J_PORT", "7687") |> String.to_integer()
    user = System.get_env("NEO4J_USER", "neo4j")
    pass = System.get_env("NEO4J_PASS", "password")

    uri = "bolt://#{host}:#{port}"
    auth = {user, pass}

    IO.puts("\n=== Neo4j Connection Test ===")
    IO.puts("URI: #{uri}")
    IO.puts("User: #{user}")
    IO.puts("=" |> String.duplicate(40))

    case Neo4jEx.start_link(uri, auth: auth) do
      {:ok, driver} ->
        IO.puts("✓ Driver started successfully")

        case test_simple_query(driver) do
          :ok ->
            IO.puts("✓ Simple query test passed")

            case test_transaction(driver) do
              :ok ->
                IO.puts("✓ Transaction test passed")
                IO.puts("\n🎉 All tests passed! Your Neo4j connection is working correctly.")

              {:error, reason} ->
                IO.puts("✗ Transaction test failed: #{inspect(reason)}")
            end

          {:error, reason} ->
            IO.puts("✗ Simple query test failed: #{inspect(reason)}")
        end

        Neo4jEx.close(driver)
        IO.puts("✓ Driver closed")

      {:error, reason} ->
        IO.puts("✗ Failed to start driver: #{inspect(reason)}")
        print_troubleshooting_guide()
    end
  end

  defp test_simple_query(driver) do
    IO.puts("\nTesting simple query...")

    case Neo4jEx.run(driver, "RETURN 1 AS number, 'Hello Neo4j!' AS greeting") do
      {:ok, results} ->
        IO.puts("  Query executed successfully")
        IO.puts("  Records returned: #{length(results.records)}")

        if length(results.records) > 0 do
          record = List.first(results.records)
          number = Neo4j.Result.Record.get(record, 0)
          greeting = Neo4j.Result.Record.get(record, 1)
          IO.puts("  Result: number=#{number}, greeting=#{greeting}")
        end

        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp test_transaction(driver) do
    IO.puts("\nTesting transaction...")

    # Create a unique label to avoid conflicts
    timestamp = System.system_time(:millisecond)
    label = "TestNode#{timestamp}"

    try do
      result = Neo4jEx.transaction(driver, fn tx ->
        # Create a test node
        {:ok, _} = Neo4j.Transaction.run(tx,
          "CREATE (n:#{label} {name: $name, created: $created}) RETURN n",
          %{name: "Test Node", created: timestamp})

        # Query the test node
        {:ok, results} = Neo4j.Transaction.run(tx,
          "MATCH (n:#{label}) RETURN n.name AS name, n.created AS created")

        results
      end)

      case result do
        {:ok, results} ->
          IO.puts("  Transaction executed successfully")
          IO.puts("  Records returned: #{length(results.records)}")

          # Clean up - delete the test node
          Neo4jEx.run(driver, "MATCH (n:#{label}) DELETE n")
          IO.puts("  Test data cleaned up")

          :ok

        {:error, reason} ->
          {:error, reason}
      end

    rescue
      error ->
        # Clean up in case of error
        Neo4jEx.run(driver, "MATCH (n:#{label}) DELETE n")
        {:error, error}
    end
  end

  defp print_troubleshooting_guide do
    IO.puts("\n" <> String.duplicate("=", 40))
    IO.puts("TROUBLESHOOTING GUIDE")
    IO.puts(String.duplicate("=", 40))
    IO.puts("""
    Common issues and solutions:

    1. Connection refused:
       - Make sure Neo4j is running
       - Check if it's listening on port 7687
       - Verify with: lsof -i :7687

    2. Authentication failed:
       - Check your username and password
       - Default Neo4j credentials: neo4j/neo4j (must be changed on first login)
       - Set custom credentials: NEO4J_USER=myuser NEO4J_PASS=mypass

    3. Custom host/port:
       - Set NEO4J_HOST=your-host NEO4J_PORT=your-port

    Example with custom settings:
    NEO4J_HOST=localhost NEO4J_PORT=7687 NEO4J_USER=neo4j NEO4J_PASS=mypassword elixir scripts/test_connection.exs
    """)
  end
end

ConnectionTest.run()
