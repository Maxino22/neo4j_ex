# Simple test to verify the driver works
IO.puts("=== Simple Neo4j Driver Test ===")

case Neo4j.Driver.start_link("bolt://localhost:7687", auth: {"neo4j", "password"}) do
  {:ok, driver} ->
    IO.puts("✓ Driver started successfully")

    case Neo4j.Driver.run(driver, "RETURN 1 as test") do
      {:ok, results} ->
        IO.puts("✓ Query executed successfully")
        IO.puts("✓ Results: #{inspect(results)}")

      {:error, reason} ->
        IO.puts("✗ Query failed: #{inspect(reason)}")
    end

    Neo4j.Driver.close(driver)
    IO.puts("✓ Driver closed")

  {:error, reason} ->
    IO.puts("✗ Driver failed to start: #{inspect(reason)}")
end

IO.puts("=== Test Complete ===")
