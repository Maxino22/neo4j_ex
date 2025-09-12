defmodule Neo4j.Application do
  @moduledoc """
  The Neo4j Application module.

  This module provides the application callback for starting the Neo4j driver
  as part of a supervision tree. It can be configured to automatically start
  Neo4j drivers based on application configuration.

  ## Configuration

  You can configure Neo4j drivers in your application configuration:

      # config/config.exs
      config :neo4j_ex,
        drivers: [
          default: [
            uri: "bolt://localhost:7687",
            auth: {"neo4j", "password"},
            connection_timeout: 15_000,
            query_timeout: 30_000
          ],
          secondary: [
            uri: "bolt://secondary:7687",
            auth: {"neo4j", "password"}
          ]
        ]

  Or configure a single default driver:

      config :neo4j_ex,
        uri: "bolt://localhost:7687",
        auth: {"neo4j", "password"}

  ## Usage in Supervision Tree

  Add to your application's supervision tree:

      # lib/my_app/application.ex
      def start(_type, _args) do
        children = [
          # Other children...
          Neo4j.Application
        ]

        opts = [strategy: :one_for_one, name: MyApp.Supervisor]
        Supervisor.start_link(children, opts)
      end

  Or start specific drivers:

      children = [
        {Neo4j.Driver, [
          name: MyApp.Neo4j,
          uri: "bolt://localhost:7687",
          auth: {"neo4j", "password"}
        ]}
      ]
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = build_children()

    opts = [strategy: :one_for_one, name: Neo4j.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc """
  Builds child specifications based on application configuration.
  """
  def build_children do
    # Always include the pool supervisor
    pool_supervisor = Neo4j.Connection.Pool.Supervisor

    driver_children = case Application.get_env(:neo4j_ex, :drivers) do
      drivers when is_list(drivers) ->
        # Multiple named drivers
        drivers
        |> Enum.map(fn {name, config} ->
          build_driver_child_spec(name, config)
        end)
        |> Enum.filter(& &1)

      nil ->
        # Check for single driver configuration
        case get_single_driver_config() do
          nil -> []
          config -> [build_driver_child_spec(:default, config)]
        end

      config when is_list(config) ->
        # Single driver as keyword list
        [build_driver_child_spec(:default, config)]
    end

    [pool_supervisor | driver_children]
  end

  defp get_single_driver_config do
    uri = Application.get_env(:neo4j_ex, :uri)
    auth = Application.get_env(:neo4j_ex, :auth)
    connection_timeout = Application.get_env(:neo4j_ex, :connection_timeout)
    query_timeout = Application.get_env(:neo4j_ex, :query_timeout)
    user_agent = Application.get_env(:neo4j_ex, :user_agent)

    if uri do
      [
        uri: uri,
        auth: auth,
        connection_timeout: connection_timeout,
        query_timeout: query_timeout,
        user_agent: user_agent
      ]
      |> Enum.filter(fn {_k, v} -> v != nil end)
    else
      nil
    end
  end

  defp build_driver_child_spec(name, config) do
    uri = Keyword.get(config, :uri)

    if uri do
      opts = Keyword.put(config, :name, name)
      {Neo4j.Driver, [uri, opts]}
    else
      Logger.warning("Neo4j driver #{name} missing :uri configuration, skipping")
      nil
    end
  end

  @doc """
  Returns a child specification for use in supervision trees.

  ## Examples

      # In your application supervisor
      children = [
        Neo4j.Application.child_spec([])
      ]

      # Or with custom options
      children = [
        Neo4j.Application.child_spec([
          drivers: [
            default: [
              uri: "bolt://localhost:7687",
              auth: {"neo4j", "password"}
            ]
          ]
        ])
      ]
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end

  @doc """
  Starts the Neo4j application supervisor.

  This is typically called automatically when the application starts,
  but can be called manually for testing or custom supervision trees.

  ## Examples

      {:ok, pid} = Neo4j.Application.start_link([])

      # With custom configuration
      {:ok, pid} = Neo4j.Application.start_link([
        drivers: [
          default: [uri: "bolt://localhost:7687", auth: {"neo4j", "password"}]
        ]
      ])
  """
  def start_link(opts \\ []) do
    # Temporarily set configuration for this start
    original_config = Application.get_all_env(:neo4j_ex)

    try do
      # Apply any provided configuration
      Enum.each(opts, fn {key, value} ->
        Application.put_env(:neo4j_ex, key, value)
      end)

      children = build_children()
      supervisor_opts = [strategy: :one_for_one, name: Neo4j.Supervisor]
      Supervisor.start_link(children, supervisor_opts)
    after
      # Restore original configuration
      Application.put_all_env([{:neo4j_ex, original_config}])
    end
  end
end
