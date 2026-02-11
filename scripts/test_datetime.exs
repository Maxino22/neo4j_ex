# Test script for datetime support
# Run with: mix run scripts/test_datetime.exs

IO.puts("Testing Neo4j datetime support...")
IO.puts("=" |> String.duplicate(50))

# Start the driver
{:ok, driver} = Neo4jEx.start_link(
  "bolt://localhost:7687",
  auth: {"neo4j", "password@12"}
)

IO.puts("\n1. Testing datetime() function:")
IO.puts("-" |> String.duplicate(50))

case Neo4jEx.run(driver, "RETURN datetime()") do
  {:ok, result} ->
    [record] = result.records
    datetime_value = hd(record.values)

    IO.puts("✓ Query successful!")
    IO.puts("  Type: #{inspect(datetime_value.__struct__)}")
    IO.puts("  Value: #{inspect(datetime_value)}")

    # Check if it's properly decoded
    if is_struct(datetime_value, Neo4j.Types.Neo4jDateTime) do
      IO.puts("\n✓ SUCCESS: datetime() is properly decoded to Neo4j.Types.Neo4jDateTime")
    else
      IO.puts("\n✗ FAIL: datetime() returned unexpected type: #{inspect(datetime_value)}")
    end

  {:error, error} ->
    IO.puts("✗ Query failed: #{inspect(error)}")
end

IO.puts("\n2. Testing time() function (for comparison):")
IO.puts("-" |> String.duplicate(50))

case Neo4jEx.run(driver, "RETURN time()") do
  {:ok, result} ->
    [record] = result.records
    time_value = hd(record.values)

    IO.puts("✓ Query successful!")
    IO.puts("  Type: #{inspect(time_value.__struct__)}")
    IO.puts("  Value: #{inspect(time_value)}")

  {:error, error} ->
    IO.puts("✗ Query failed: #{inspect(error)}")
end

IO.puts("\n3. Testing date() function:")
IO.puts("-" |> String.duplicate(50))

case Neo4jEx.run(driver, "RETURN date()") do
  {:ok, result} ->
    [record] = result.records
    date_value = hd(record.values)

    IO.puts("✓ Query successful!")
    IO.puts("  Type: #{inspect(date_value.__struct__)}")
    IO.puts("  Value: #{inspect(date_value)}")

  {:error, error} ->
    IO.puts("✗ Query failed: #{inspect(error)}")
end

IO.puts("\n4. Testing localdatetime() function:")
IO.puts("-" |> String.duplicate(50))

case Neo4jEx.run(driver, "RETURN localdatetime()") do
  {:ok, result} ->
    [record] = result.records
    localdatetime_value = hd(record.values)

    IO.puts("✓ Query successful!")
    IO.puts("  Type: #{inspect(localdatetime_value.__struct__)}")
    IO.puts("  Value: #{inspect(localdatetime_value)}")

  {:error, error} ->
    IO.puts("✗ Query failed: #{inspect(error)}")
end

IO.puts("\n5. Testing datetime with explicit timezone:")
IO.puts("-" |> String.duplicate(50))

case Neo4jEx.run(driver, "RETURN datetime({timezone: 'America/New_York'})") do
  {:ok, result} ->
    [record] = result.records
    datetime_value = hd(record.values)

    IO.puts("✓ Query successful!")
    IO.puts("  Type: #{inspect(datetime_value.__struct__)}")
    IO.puts("  Value: #{inspect(datetime_value)}")
    IO.puts("  Timezone ID: #{datetime_value.timezone_id}")

  {:error, error} ->
    IO.puts("✗ Query failed: #{inspect(error)}")
end

# Clean up
GenServer.stop(driver)

IO.puts("\n" <> "=" |> String.duplicate(50))
IO.puts("Test complete!")
