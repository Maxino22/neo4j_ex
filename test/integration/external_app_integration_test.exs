defmodule Neo4jEx.ExternalAppIntegrationTest do
  @moduledoc """
  Integration tests to verify that neo4j_ex works correctly when used as a dependency
  in external applications, similar to how Ecto is used.
  """

  use ExUnit.Case, async: false
  require Logger

  @moduletag :integration

  describe "external application integration" do
    test "starts driver with single configuration like Ecto" do
      # Simulate external app configuration
      original_config = Application.get_all_env(:neo4j_ex)

      try do
        # Set configuration like an external app would
        Application.put_env(:neo4j_ex, :uri, "bolt://localhost:7687")
        Application.put_env(:neo4j_ex, :auth, {"neo4j", "password"})
        Application.put_env(:neo4j_ex, :connection_timeout, 15_000)
        Application.put_env(:neo4j_ex, :query_timeout, 30_000)

        # Start the application supervisor with unique name
        supervisor_name = :"Neo4j.TestSupervisor.#{System.unique_integer([:positive])}"
        children = Neo4j.Application.build_children()
        {:ok, supervisor_pid} = Supervisor.start_link(children, strategy: :one_for_one, name: supervisor_name)

        # Verify the supervisor started
        assert Process.alive?(supervisor_pid)

        # Verify the default driver is running
        assert Process.whereis(:default) != nil

        # Test that we can get the driver config
        config = Neo4j.Driver.get_config(:default)
        assert config.host == "localhost"
        assert config.port == 7687
        assert config.auth["principal"] == "neo4j"
        assert config.auth["credentials"] == "password"

        # Clean up
        Supervisor.stop(supervisor_pid)
      after
        # Restore original configuration
        Application.put_all_env([{:neo4j_ex, original_config}])
      end
    end

    test "starts multiple drivers with drivers configuration" do
      original_config = Application.get_all_env(:neo4j_ex)

      try do
        # Set multiple drivers configuration
        Application.put_env(:neo4j_ex, :drivers, [
          primary: [
            uri: "bolt://localhost:7687",
            auth: {"neo4j", "password"},
            connection_timeout: 15_000
          ],
          secondary: [
            uri: "bolt://localhost:7688",
            auth: {"neo4j", "password2"},
            connection_timeout: 20_000
          ]
        ])

        # Start the application supervisor with unique name
        supervisor_name = :"Neo4j.TestSupervisor.#{System.unique_integer([:positive])}"
        children = Neo4j.Application.build_children()
        {:ok, supervisor_pid} = Supervisor.start_link(children, strategy: :one_for_one, name: supervisor_name)

        # Verify the supervisor started
        assert Process.alive?(supervisor_pid)

        # Verify both drivers are running
        assert Process.whereis(:primary) != nil
        assert Process.whereis(:secondary) != nil

        # Test that we can get configs for both drivers
        primary_config = Neo4j.Driver.get_config(:primary)
        assert primary_config.host == "localhost"
        assert primary_config.port == 7687

        secondary_config = Neo4j.Driver.get_config(:secondary)
        assert secondary_config.host == "localhost"
        assert secondary_config.port == 7688

        # Clean up
        Supervisor.stop(supervisor_pid)
      after
        # Restore original configuration
        Application.put_all_env([{:neo4j_ex, original_config}])
      end
    end

    test "handles missing URI configuration gracefully" do
      original_config = Application.get_all_env(:neo4j_ex)

      try do
        # Set configuration without URI
        Application.put_env(:neo4j_ex, :auth, {"neo4j", "password"})
        Application.put_env(:neo4j_ex, :connection_timeout, 15_000)

        # Start the application supervisor with unique name
        supervisor_name = :"Neo4j.TestSupervisor.#{System.unique_integer([:positive])}"
        children = Neo4j.Application.build_children()
        {:ok, supervisor_pid} = Supervisor.start_link(children, strategy: :one_for_one, name: supervisor_name)

        # Verify the supervisor started (even without drivers)
        assert Process.alive?(supervisor_pid)

        # Verify no default driver is running
        assert Process.whereis(:default) == nil

        # Clean up
        Supervisor.stop(supervisor_pid)
      after
        # Restore original configuration
        Application.put_all_env([{:neo4j_ex, original_config}])
      end
    end

    test "child specification format is correct" do
      config = [
        uri: "bolt://localhost:7687",
        auth: {"neo4j", "password"},
        connection_timeout: 15_000
      ]

      # Test the child spec building function directly
      child_spec = Neo4j.Application.build_driver_child_spec(:test_driver, config)

      # Verify it's a proper child specification map
      assert is_map(child_spec)
      assert child_spec.id == :test_driver
      assert {module, function, args} = child_spec.start
      assert module == Neo4j.Driver
      assert function == :start_link
      assert [uri, opts] = args
      assert uri == "bolt://localhost:7687"
      assert opts[:name] == :test_driver
      assert opts[:auth] == {"neo4j", "password"}
    end

    test "build_children returns correct structure" do
      original_config = Application.get_all_env(:neo4j_ex)

      try do
        # Set single driver configuration
        Application.put_env(:neo4j_ex, :uri, "bolt://localhost:7687")
        Application.put_env(:neo4j_ex, :auth, {"neo4j", "password"})

        children = Neo4j.Application.build_children()

        # Should have pool supervisor and default driver
        assert length(children) == 2

        # First child should be pool supervisor
        assert List.first(children) == Neo4j.Connection.Pool.Supervisor

        # Second child should be the driver child spec
        driver_spec = List.last(children)
        assert is_map(driver_spec)
        assert driver_spec.id == :default
      after
        # Restore original configuration
        Application.put_all_env([{:neo4j_ex, original_config}])
      end
    end
  end

  describe "Ecto-like behavior verification" do
    test "can be included in external app supervision tree" do
      # This test simulates how an external app would include neo4j_ex
      original_config = Application.get_all_env(:neo4j_ex)

      try do
        # Set configuration
        Application.put_env(:neo4j_ex, :uri, "bolt://localhost:7687")
        Application.put_env(:neo4j_ex, :auth, {"neo4j", "password"})

        # Create a supervision tree like an external app would
        children = [
          # Simulate other app children
          %{id: :dummy_worker, start: {Task, :start_link, [fn -> :timer.sleep(1000) end]}},
          # Include Neo4j.Application like Ecto.Repo
          Neo4j.Application
        ]

        {:ok, supervisor_pid} = Supervisor.start_link(children, strategy: :one_for_one)

        # Verify everything started correctly
        assert Process.alive?(supervisor_pid)
        assert Process.whereis(:default) != nil

        # Verify we can use the driver
        config = Neo4j.Driver.get_config(:default)
        assert config.host == "localhost"

        # Clean up
        Supervisor.stop(supervisor_pid)
      after
        # Restore original configuration
        Application.put_all_env([{:neo4j_ex, original_config}])
      end
    end

    test "configuration is read from application environment like Ecto" do
      original_config = Application.get_all_env(:neo4j_ex)

      try do
        # Test the exact configuration format from the user's issue
        Application.put_env(:neo4j_ex, :uri, "bolt://localhost:7687")
        Application.put_env(:neo4j_ex, :auth, {"neo4j", "password"})
        Application.put_env(:neo4j_ex, :connection_timeout, 15_000)
        Application.put_env(:neo4j_ex, :query_timeout, 30_000)

        # Get single driver config (this is what was failing)
        config = Neo4j.Application.get_single_driver_config()

        assert config[:uri] == "bolt://localhost:7687"
        assert config[:auth] == {"neo4j", "password"}
        assert config[:connection_timeout] == 15_000
        assert config[:query_timeout] == 30_000

        # Build child spec with this config
        child_spec = Neo4j.Application.build_driver_child_spec(:default, config)

        # Verify the child spec is properly formatted
        assert child_spec.id == :default
        assert {Neo4j.Driver, :start_link, [uri, opts]} = child_spec.start
        assert uri == "bolt://localhost:7687"
        assert opts[:auth] == {"neo4j", "password"}
      after
        # Restore original configuration
        Application.put_all_env([{:neo4j_ex, original_config}])
      end
    end
  end
end
