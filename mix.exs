defmodule Neo4jEx.MixProject do
  use Mix.Project

  @version "0.1.9"
  @source_url "https://github.com/Maxino22/neo4j_ex"

  def project do
    [
      app: :neo4j_ex,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "Neo4jEx",
      source_url: @source_url,
      homepage_url: @source_url,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Neo4j.Application, []}
    ]
  end

  defp deps do
    [
      # Connection pooling
      {:poolboy, "~> 1.5"},

      # Development and testing
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    """
    A pure Elixir driver for Neo4j graph database using the Bolt protocol.
    Supports authentication, query execution, transactions, and connection management.
    """
  end

  defp package do
    [
      name: "neo4j_ex",
      files: ~w(lib .formatter.exs mix.exs README* CHANGELOG* LICENSE*),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md",
        "Documentation" => "https://hexdocs.pm/neo4j_ex"
      },
      maintainers: ["Maxino22 <ajaybullec@gmail.com>"]
    ]
  end

  defp docs do
    [
      main: "Neo4jEx",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: [
        "README.md",
        "CHANGELOG.md",
        "IMPLEMENTATION_GUIDE.md"
      ],
      groups_for_modules: [
        "Core API": [
          Neo4jEx,
          Neo4j.Driver
        ],
        "Session & Transactions": [
          Neo4j.Session,
          Neo4j.Transaction
        ],
        "Protocol Implementation": [
          Neo4j.Protocol.Messages,
          Neo4j.Protocol.PackStream,
          Neo4j.Protocol.Bolt
        ],
        "Connection Management": [
          Neo4j.Connection.Socket,
          Neo4j.Connection.Handshake,
          Neo4j.Connection.Pool
        ],
        "Results & Types": [
          Neo4j.Result.Record,
          Neo4j.Result.Summary,
          Neo4j.Types.Node,
          Neo4j.Types.Relationship,
          Neo4j.Types.Path
        ]
      ]
    ]
  end
end
