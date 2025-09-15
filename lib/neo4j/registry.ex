defmodule Neo4j.Registry do
  @moduledoc """
  Registry for managing named Neo4j drivers.

  This module provides functions to register, lookup, and manage named Neo4j drivers
  within the application supervision tree. It enables the use of driver names like
  `:default` instead of requiring explicit driver PIDs.

  ## Usage

      # Look up a driver by name
      {:ok, driver} = Neo4j.Registry.lookup(:default)

      # Check if a driver is registered
      true = Neo4j.Registry.registered?(:default)

      # List all registered drivers
      [:default, :analytics] = Neo4j.Registry.list_drivers()
  """

  @doc """
  Looks up a driver by name or returns the driver if it's already a PID.

  ## Parameters
    - driver_ref: Driver name (atom) or driver PID

  ## Returns
    - `{:ok, driver_pid}` if found
    - `{:error, :not_found}` if driver name is not registered
    - `{:error, :not_running}` if driver process is not alive

  ## Examples

      {:ok, driver} = Neo4j.Registry.lookup(:default)
      {:ok, driver} = Neo4j.Registry.lookup(some_pid)
      {:error, :not_found} = Neo4j.Registry.lookup(:nonexistent)
  """
  def lookup(driver_ref) when is_pid(driver_ref) do
    if Process.alive?(driver_ref) do
      {:ok, driver_ref}
    else
      {:error, :not_running}
    end
  end

  def lookup(driver_name) when is_atom(driver_name) do
    case find_driver_in_supervision_tree(driver_name) do
      {:ok, pid} -> {:ok, pid}
      :not_found -> {:error, :not_found}
    end
  end

  def lookup(driver_ref) do
    {:error, {:invalid_driver_ref, driver_ref}}
  end

  @doc """
  Looks up a driver by name, raising an error if not found.

  ## Parameters
    - driver_ref: Driver name (atom) or driver PID

  ## Returns
    Driver PID

  ## Raises
    `RuntimeError` if driver is not found or not running

  ## Examples

      driver = Neo4j.Registry.lookup!(:default)
      driver = Neo4j.Registry.lookup!(some_pid)
  """
  def lookup!(driver_ref) do
    case lookup(driver_ref) do
      {:ok, driver} -> driver
      {:error, :not_found} -> raise "Neo4j driver #{inspect(driver_ref)} not found"
      {:error, :not_running} -> raise "Neo4j driver #{inspect(driver_ref)} is not running"
      {:error, {:invalid_driver_ref, ref}} -> raise "Invalid driver reference: #{inspect(ref)}"
    end
  end

  @doc """
  Checks if a driver is registered and running.

  ## Parameters
    - driver_name: Driver name (atom)

  ## Returns
    `true` if registered and running, `false` otherwise

  ## Examples

      true = Neo4j.Registry.registered?(:default)
      false = Neo4j.Registry.registered?(:nonexistent)
  """
  def registered?(driver_name) when is_atom(driver_name) do
    case lookup(driver_name) do
      {:ok, _driver} -> true
      {:error, _reason} -> false
    end
  end

  @doc """
  Lists all registered driver names.

  ## Returns
    List of driver names (atoms)

  ## Examples

      [:default, :analytics] = Neo4j.Registry.list_drivers()
  """
  def list_drivers do
    case find_supervisor() do
      {:ok, supervisor} ->
        supervisor
        |> Supervisor.which_children()
        |> Enum.filter(fn {_id, pid, _type, modules} ->
          is_pid(pid) and Process.alive?(pid) and Neo4j.Driver in List.wrap(modules)
        end)
        |> Enum.map(fn {id, _pid, _type, _modules} -> id end)
        |> Enum.filter(&is_atom/1)

      :not_found ->
        []
    end
  end

  # Private Functions

  defp find_driver_in_supervision_tree(driver_name) do
    case find_supervisor() do
      {:ok, supervisor} ->
        case find_child_by_id(supervisor, driver_name) do
          {:ok, pid} -> {:ok, pid}
          :not_found -> :not_found
        end

      :not_found ->
        :not_found
    end
  end

  defp find_supervisor do
    # Try to find the Neo4j supervisor
    case Process.whereis(Neo4j.Supervisor) do
      pid when is_pid(pid) -> {:ok, pid}
      nil -> :not_found
    end
  end

  defp find_child_by_id(supervisor, child_id) do
    children = Supervisor.which_children(supervisor)

    case Enum.find(children, fn {id, _child, _type, _modules} -> id == child_id end) do
      {^child_id, pid, _type, _modules} when is_pid(pid) ->
        if Process.alive?(pid) do
          {:ok, pid}
        else
          :not_found
        end

      nil ->
        :not_found
    end
  end
end
