# Test script for Person nodes using the Neo4j driver

defmodule PersonNodeTest do
  def run do
    IO.puts("=== Testing Neo4j Driver with Person Nodes ===")

    # Connect to Neo4j
    IO.puts("1. Connecting to Neo4j...")
    case Neo4j.Driver.start_link("bolt://localhost:7687", auth: {"neo4j", "password"}) do
      {:ok, driver} ->
        IO.puts("   ✓ Connected successfully")

        try do
          # Test 1: Count existing Person nodes
          IO.puts("\n2. Counting existing Person nodes...")
          case Neo4j.Driver.run(driver, "MATCH (n:Person) RETURN count(n) as count") do
            {:ok, results} ->
              count = results |> Enum.at(0) |> Map.get("count")
              IO.puts("   ✓ Found #{count} Person nodes")

            {:error, reason} ->
              IO.puts("   ✗ Count query failed: #{inspect(reason)}")
          end

          # Test 2: Get first 5 Person nodes
          IO.puts("\n3. Fetching first 5 Person nodes...")
          case Neo4j.Driver.run(driver, "MATCH (n:Person) RETURN n.name as name LIMIT 5") do
            {:ok, results} ->
              IO.puts("   ✓ Retrieved #{length(results)} Person nodes:")
              Enum.each(results, fn person ->
                IO.puts("     - #{person["name"]}")
              end)

            {:error, reason} ->
              IO.puts("   ✗ Fetch query failed: #{inspect(reason)}")
          end

          # Test 3: Create a test Person node
          IO.puts("\n4. Creating a test Person node...")
          test_name = "TestPerson_#{:rand.uniform(1000)}"
          case Neo4j.Driver.run(driver, "CREATE (p:Person {name: $name}) RETURN p.name as name", %{name: test_name}) do
            {:ok, results} ->
              created_name = results |> Enum.at(0) |> Map.get("name")
              IO.puts("   ✓ Created Person: #{created_name}")

              # Test 4: Find the created Person
              IO.puts("\n5. Finding the created Person...")
              case Neo4j.Driver.run(driver, "MATCH (p:Person {name: $name}) RETURN p.name as name", %{name: test_name}) do
                {:ok, results} ->
                  found_name = results |> Enum.at(0) |> Map.get("name")
                  IO.puts("   ✓ Found Person: #{found_name}")

                  # Test 5: Delete the test Person
                  IO.puts("\n6. Cleaning up test Person...")
                  case Neo4j.Driver.run(driver, "MATCH (p:Person {name: $name}) DELETE p", %{name: test_name}) do
                    {:ok, _results} ->
                      IO.puts("   ✓ Test Person deleted")

                    {:error, reason} ->
                      IO.puts("   ✗ Delete failed: #{inspect(reason)}")
                  end

                {:error, reason} ->
                  IO.puts("   ✗ Find query failed: #{inspect(reason)}")
              end

            {:error, reason} ->
              IO.puts("   ✗ Create query failed: #{inspect(reason)}")
          end

          # Test 6: Transaction test
          IO.puts("\n7. Testing transaction...")
          result = Neo4j.Driver.transaction(driver, fn tx ->
            # Create two test persons in a transaction
            name1 = "TxPerson1_#{:rand.uniform(1000)}"
            name2 = "TxPerson2_#{:rand.uniform(1000)}"

            {:ok, _} = Neo4j.Transaction.run(tx, "CREATE (p:Person {name: $name})", %{name: name1})
            {:ok, _} = Neo4j.Transaction.run(tx, "CREATE (p:Person {name: $name})", %{name: name2})

            # Return the names for cleanup
            {name1, name2}
          end)

          case result do
            {:ok, {name1, name2}} ->
              IO.puts("   ✓ Transaction completed successfully")

              # Cleanup transaction test persons
              Neo4j.Driver.run(driver, "MATCH (p:Person) WHERE p.name IN [$name1, $name2] DELETE p", %{name1: name1, name2: name2})
              IO.puts("   ✓ Transaction test persons cleaned up")

            {:error, reason} ->
              IO.puts("   ✗ Transaction failed: #{inspect(reason)}")
          end

        after
          Neo4j.Driver.close(driver)
          IO.puts("\n8. Driver closed")
        end

      {:error, reason} ->
        IO.puts("   ✗ Connection failed: #{inspect(reason)}")
    end

    IO.puts("\n=== Test Complete ===")
  end
end

# Run the test
PersonNodeTest.run()
