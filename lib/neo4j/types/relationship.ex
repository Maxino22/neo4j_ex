defmodule Neo4j.Types.Relationship do
  @moduledoc """
  Represents a Neo4j Relationship.

  A relationship contains an ID, start/end node IDs, type, and properties.
  """

  defstruct [:id, :start_id, :end_id, :type, :properties, :element_id]

  @type t :: %__MODULE__{
    id: integer(),
    start_id: integer(),
    end_id: integer(),
    type: String.t(),
    properties: map(),
    element_id: String.t() | nil
  }

  @doc """
  Creates a new Relationship from Neo4j data.

  ## Parameters
    - id: Relationship ID (integer)
    - start_id: Start node ID (integer)
    - end_id: End node ID (integer)
    - type: Relationship type string
    - properties: Map of properties
    - element_id: Optional element ID string (Neo4j 5.0+)

  ## Returns
    New Relationship struct

  ## Examples

      rel = Neo4j.Types.Relationship.new(456, 123, 789, "KNOWS", %{"since" => 2020})
      rel = Neo4j.Types.Relationship.new(456, 123, 789, "KNOWS", %{}, "5:abc123:456")
  """
  def new(id, start_id, end_id, type, properties, element_id \\ nil) do
    %__MODULE__{
      id: id,
      start_id: start_id,
      end_id: end_id,
      type: type,
      properties: properties,
      element_id: element_id
    }
  end

  @doc """
  Gets a property value from the relationship.

  ## Parameters
    - relationship: Relationship struct
    - key: Property key (string or atom)

  ## Returns
    Property value or nil if not found

  ## Examples

      value = Neo4j.Types.Relationship.get_property(rel, "since")
      value = Neo4j.Types.Relationship.get_property(rel, :since)
  """
  def get_property(%__MODULE__{properties: properties}, key) when is_atom(key) do
    Map.get(properties, to_string(key))
  end

  def get_property(%__MODULE__{properties: properties}, key) when is_binary(key) do
    Map.get(properties, key)
  end

  @doc """
  Gets all properties from the relationship.

  ## Parameters
    - relationship: Relationship struct

  ## Returns
    Map of properties

  ## Examples

      properties = Neo4j.Types.Relationship.properties(rel)
  """
  def properties(%__MODULE__{properties: properties}), do: properties

  @doc """
  Gets the relationship ID.

  ## Parameters
    - relationship: Relationship struct

  ## Returns
    Relationship ID (integer)

  ## Examples

      id = Neo4j.Types.Relationship.id(rel)
  """
  def id(%__MODULE__{id: id}), do: id

  @doc """
  Gets the relationship type.

  ## Parameters
    - relationship: Relationship struct

  ## Returns
    Relationship type string

  ## Examples

      type = Neo4j.Types.Relationship.type(rel)
  """
  def type(%__MODULE__{type: type}), do: type

  @doc """
  Gets the start node ID.

  ## Parameters
    - relationship: Relationship struct

  ## Returns
    Start node ID (integer)

  ## Examples

      start_id = Neo4j.Types.Relationship.start_id(rel)
  """
  def start_id(%__MODULE__{start_id: start_id}), do: start_id

  @doc """
  Gets the end node ID.

  ## Parameters
    - relationship: Relationship struct

  ## Returns
    End node ID (integer)

  ## Examples

      end_id = Neo4j.Types.Relationship.end_id(rel)
  """
  def end_id(%__MODULE__{end_id: end_id}), do: end_id

  @doc """
  Gets the element ID (Neo4j 5.0+).

  ## Parameters
    - relationship: Relationship struct

  ## Returns
    Element ID string or nil

  ## Examples

      element_id = Neo4j.Types.Relationship.element_id(rel)
  """
  def element_id(%__MODULE__{element_id: element_id}), do: element_id
end
