defmodule Neo4j.Types.Path do
  @moduledoc """
  Represents a Neo4j Path.

  A path contains a sequence of nodes and relationships.
  """

  defstruct [:nodes, :relationships, :indices]

  @type t :: %__MODULE__{
    nodes: [Neo4j.Types.Node.t()],
    relationships: [Neo4j.Types.Relationship.t()],
    indices: [integer()]
  }

  @doc """
  Creates a new Path from Neo4j data.

  ## Parameters
    - nodes: List of nodes in the path
    - relationships: List of relationships in the path
    - indices: List of relationship indices

  ## Returns
    New Path struct

  ## Examples

      path = Neo4j.Types.Path.new([node1, node2], [rel1], [0])
  """
  def new(nodes, relationships, indices) do
    %__MODULE__{
      nodes: nodes,
      relationships: relationships,
      indices: indices
    }
  end

  @doc """
  Gets all nodes in the path.

  ## Parameters
    - path: Path struct

  ## Returns
    List of nodes

  ## Examples

      nodes = Neo4j.Types.Path.nodes(path)
  """
  def nodes(%__MODULE__{nodes: nodes}), do: nodes

  @doc """
  Gets all relationships in the path.

  ## Parameters
    - path: Path struct

  ## Returns
    List of relationships

  ## Examples

      relationships = Neo4j.Types.Path.relationships(path)
  """
  def relationships(%__MODULE__{relationships: relationships}), do: relationships

  @doc """
  Gets the length of the path (number of relationships).

  ## Parameters
    - path: Path struct

  ## Returns
    Path length (integer)

  ## Examples

      length = Neo4j.Types.Path.length(path)
  """
  def length(%__MODULE__{relationships: relationships}), do: Kernel.length(relationships)

  @doc """
  Gets the start node of the path.

  ## Parameters
    - path: Path struct

  ## Returns
    Start node or nil if path is empty

  ## Examples

      start_node = Neo4j.Types.Path.start_node(path)
  """
  def start_node(%__MODULE__{nodes: []}), do: nil
  def start_node(%__MODULE__{nodes: [first | _]}), do: first

  @doc """
  Gets the end node of the path.

  ## Parameters
    - path: Path struct

  ## Returns
    End node or nil if path is empty

  ## Examples

      end_node = Neo4j.Types.Path.end_node(path)
  """
  def end_node(%__MODULE__{nodes: []}), do: nil
  def end_node(%__MODULE__{nodes: nodes}), do: List.last(nodes)
end
