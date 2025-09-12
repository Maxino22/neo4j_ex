defmodule Neo4j.Types.Node do
  @moduledoc """
  Represents a Neo4j Node.

  A node contains an ID, labels, and properties.
  """

  defstruct [:id, :labels, :properties, :element_id]

  @type t :: %__MODULE__{
    id: integer(),
    labels: [String.t()],
    properties: map(),
    element_id: String.t() | nil
  }

  @doc """
  Creates a new Node from Neo4j data.

  ## Parameters
    - id: Node ID (integer)
    - labels: List of label strings
    - properties: Map of properties
    - element_id: Optional element ID string (Neo4j 5.0+)

  ## Returns
    New Node struct

  ## Examples

      node = Neo4j.Types.Node.new(123, ["Person"], %{"name" => "Alice", "age" => 30})
      node = Neo4j.Types.Node.new(123, ["Person"], %{"name" => "Alice"}, "4:abc123:123")
  """
  def new(id, labels, properties, element_id \\ nil) do
    %__MODULE__{
      id: id,
      labels: labels,
      properties: properties,
      element_id: element_id
    }
  end

  @doc """
  Gets a property value from the node.

  ## Parameters
    - node: Node struct
    - key: Property key (string or atom)

  ## Returns
    Property value or nil if not found

  ## Examples

      value = Neo4j.Types.Node.get_property(node, "name")
      value = Neo4j.Types.Node.get_property(node, :name)
  """
  def get_property(%__MODULE__{properties: properties}, key) when is_atom(key) do
    Map.get(properties, to_string(key))
  end

  def get_property(%__MODULE__{properties: properties}, key) when is_binary(key) do
    Map.get(properties, key)
  end

  @doc """
  Checks if the node has a specific label.

  ## Parameters
    - node: Node struct
    - label: Label to check for

  ## Returns
    true if the node has the label, false otherwise

  ## Examples

      has_label? = Neo4j.Types.Node.has_label?(node, "Person")
  """
  def has_label?(%__MODULE__{labels: labels}, label) do
    label in labels
  end

  @doc """
  Gets all labels from the node.

  ## Parameters
    - node: Node struct

  ## Returns
    List of label strings

  ## Examples

      labels = Neo4j.Types.Node.labels(node)
  """
  def labels(%__MODULE__{labels: labels}), do: labels

  @doc """
  Gets all properties from the node.

  ## Parameters
    - node: Node struct

  ## Returns
    Map of properties

  ## Examples

      properties = Neo4j.Types.Node.properties(node)
  """
  def properties(%__MODULE__{properties: properties}), do: properties

  @doc """
  Gets the node ID.

  ## Parameters
    - node: Node struct

  ## Returns
    Node ID (integer)

  ## Examples

      id = Neo4j.Types.Node.id(node)
  """
  def id(%__MODULE__{id: id}), do: id

  @doc """
  Gets the element ID (Neo4j 5.0+).

  ## Parameters
    - node: Node struct

  ## Returns
    Element ID string or nil

  ## Examples

      element_id = Neo4j.Types.Node.element_id(node)
  """
  def element_id(%__MODULE__{element_id: element_id}), do: element_id
end
