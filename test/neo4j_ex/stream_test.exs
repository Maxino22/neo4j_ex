defmodule Neo4j.StreamTest do
  use ExUnit.Case, async: false
  doctest Neo4j.Stream

  @moduletag :capture_log

  setup do
    # Get test configuration
    host = System.get_env("NEO4J_HOST", "localhost")
    port = System.get_env("NEO4J_PORT", "7687")
    user = System.get_env("NEO4J_USER", "neo4j")
    pass = System.get_env("NEO4J_PASS", "password")

    uri = "bolt://" <> host <> ":" <> port

    # Start the driver
    {:ok, driver} = Neo4jEx.start_link(uri, auth: {user, pass})

    on_exit(fn ->
      try do
        Neo4jEx.close(driver)
      catch
        :exit, _ -> :ok
      end
    end)

    {:ok, driver: driver}
  end

  test "stream with basic query", %{driver: driver} do
    # Create some test data
    {:ok, _} = Neo4jEx.run(driver, "UNWIND range(1, 100) AS i CREATE (n:TestStream {id: i})")

    # Test streaming
    records =
      driver
      |> Neo4j.Stream.run("MATCH (n:TestStream) RETURN n ORDER BY n.id", %{}, batch_size: 10)
      |> Enum.to_list()

    assert length(records) == 100

    # Clean up
    {:ok, _} = Neo4jEx.run(driver, "MATCH (n:TestStream) DELETE n")
  end

  test "stream with parameterized query", %{driver: driver} do
    # Create some test data
    {:ok, _} = Neo4jEx.run(driver, "UNWIND range(1, 50) AS i CREATE (n:TestStreamParam {id: i, value: i * 2})")

    # Test streaming with parameters
    records =
      driver
      |> Neo4j.Stream.run("MATCH (n:TestStreamParam) WHERE n.id > $min_id RETURN n ORDER BY n.id", %{min_id: 25}, batch_size: 5)
      |> Enum.to_list()

    assert length(records) == 25

    # Verify data
    first_record = List.first(records)
    # The record should contain the node - get it properly
    first_node = case first_record do
      %Neo4j.Result.Record{} -> Neo4j.Result.Record.get(first_record, 0)
      %Neo4j.Types.Node{} -> first_record
    end
    assert Neo4j.Types.Node.get_property(first_node, "id") == 26

    # Clean up
    {:ok, _} = Neo4jEx.run(driver, "MATCH (n:TestStreamParam) DELETE n")
  end

  test "stream with custom processor function", %{driver: driver} do
    # Create some test data
    {:ok, _} = Neo4jEx.run(driver, "UNWIND range(1, 30) AS i CREATE (n:TestStreamProcessor {id: i})")

    # Test streaming with custom processor
    results =
      driver
      |> Neo4j.Stream.run_with("MATCH (n:TestStreamProcessor) RETURN n ORDER BY n.id", %{},
        fn record ->
          # Handle both Record and direct Node cases
          node = case record do
            %Neo4j.Result.Record{} -> Neo4j.Result.Record.get(record, 0)
            %Neo4j.Types.Node{} -> record
          end
          Neo4j.Types.Node.get_property(node, "id")
        end,
        batch_size: 7)
      |> Enum.to_list()

    assert length(results) == 30
    assert List.first(results) == 1
    assert List.last(results) == 30

    # Clean up
    {:ok, _} = Neo4jEx.run(driver, "MATCH (n:TestStreamProcessor) DELETE n")
  end

  test "stream with empty result set", %{driver: driver} do
    # Test streaming with query that returns no results
    records =
      driver
      |> Neo4j.Stream.run("MATCH (n:NonExistentLabel) RETURN n", %{}, batch_size: 5)
      |> Enum.to_list()

    assert length(records) == 0
  end

  test "stream integration with Neo4jEx.stream/4", %{driver: driver} do
    # Create some test data
    {:ok, _} = Neo4jEx.run(driver, "UNWIND range(1, 25) AS i CREATE (n:TestIntegration {id: i})")

    # Test integration with Neo4jEx.stream
    records =
      driver
      |> Neo4jEx.stream("MATCH (n:TestIntegration) RETURN n ORDER BY n.id", %{}, batch_size: 8)
      |> Enum.to_list()

    assert length(records) == 25

    # Clean up
    {:ok, _} = Neo4jEx.run(driver, "MATCH (n:TestIntegration) DELETE n")
  end
end
