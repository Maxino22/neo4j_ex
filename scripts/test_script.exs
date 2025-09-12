#!/usr/bin/env elixir

# Test the connection in a script
Mix.install([
  {:neo4j_ex, path: "."}
])

{:ok, driver} = Neo4jEx.start_link("bolt://localhost:7687", auth: {"neo4j", "password"})
IO.inspect(driver)

case Neo4jEx.run(driver, "RETURN 1 AS number, 'Hello Neo4j!' AS greeting") do
  {:ok, results} ->
    IO.puts("Query executed successfully")
    IO.puts("Records returned: #{length(results.records)}")
    
    if length(results.records) > 0 do
      record = List.first(results.records)
      number = Neo4j.Result.Record.get(record, 0)
      greeting = Neo4j.Result.Record.get(record, 1)
      IO.puts("Result: number=#{number}, greeting=#{greeting}")
    end
    
  {:error, reason} ->
    IO.puts("Query failed: #{inspect(reason)}")
end

Neo4jEx.close(driver)
IO.puts("Driver closed")