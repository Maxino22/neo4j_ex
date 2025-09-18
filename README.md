# Neo4jEx

A pure Elixir driver for Neo4j graph database using the Bolt protocol.

[![Hex.pm](https://img.shields.io/hexpm/v/neo4j_ex.svg)](https://hex.pm/packages/neo4j_ex)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/neo4j_ex)
[![License](https://img.shields.io/hexpm/l/neo4j_ex.svg)](LICENSE)
[![Beta](https://img.shields.io/badge/status-beta-orange.svg)](https://github.com/Maxino22/neo4j_ex)

> **⚠️ Beta Release**: This driver is currently in beta. While core functionality is stable and tested, some edge cases and advanced features are still being refined. Please report any issues you encounter to help us improve the driver.

## Features

- **Full Bolt Protocol Support**: Complete implementation of Neo4j's Bolt protocol v5.x
- **Authentication**: Support for basic authentication and no-auth scenarios
- **Connection Management**: Automatic connection handling and cleanup
- **Query Execution**: Simple query execution with parameter support
- **Transactions**: Full transaction support with automatic commit/rollback
- **Sessions**: Session-based query execution for better resource management
- **Type Safety**: Proper handling of Neo4j data types and PackStream serialization
- **Error Handling**: Comprehensive error handling and reporting
- **Connection Pooling**: Efficient connection pooling for high-performance applications
- **Pure Elixir**: No external dependencies, built entirely in Elixir


## Installation

Add `neo4j_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:neo4j_ex, "~> 0.1.4"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Quick Start

### With Application Configuration (Recommended)

Configure your default driver in `config/config.exs`:

```elixir
# config/config.exs
config :neo4j_ex,
  uri: "bolt://localhost:7687",
  auth: {"neo4j", "password"}
```

Add Neo4j.Application to your supervision tree:

```elixir
# lib/my_app/application.ex
def start(_type, _args) do
  children = [
    # Other children...
    Neo4j.Application
  ]
  
  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

Now you can use the clean, implicit API:

```elixir
# Execute queries without passing driver explicitly
{:ok, results} = Neo4jEx.run("MATCH (n:Person) RETURN n.name LIMIT 10")

# Work with sessions using default driver
result = Neo4jEx.session(fn session ->
  Neo4j.Session.run(session, "CREATE (p:Person {name: $name})", %{name: "Alice"})
end)

# Use transactions with default driver
result = Neo4jEx.transaction(fn tx ->
  Neo4j.Transaction.run(tx, "CREATE (p:Person {name: $name})", %{name: "Bob"})
  Neo4j.Transaction.run(tx, "CREATE (p:Person {name: $name})", %{name: "Carol"})
end)

# Stream large result sets using default driver
Neo4jEx.stream("MATCH (n:Person) RETURN n")
|> Stream.each(&process_record/1)
|> Stream.run()
```

### Manual Driver Management

If you prefer explicit driver management:

```elixir
# Start a driver
{:ok, driver} = Neo4jEx.start_link("bolt://localhost:7687",
  auth: {"neo4j", "password"})

# Execute a simple query
{:ok, results} = Neo4jEx.run(driver, "MATCH (n:Person) RETURN n.name LIMIT 10")

# Process results
for record <- results.records do
  name = Neo4j.Result.Record.get(record, "n.name")
  IO.puts("Person: #{name}")
end

# Clean up
Neo4jEx.close(driver)
```

## Configuration

### Basic Configuration

```elixir
# Basic authentication
{:ok, driver} = Neo4jEx.start_link("bolt://localhost:7687",
  auth: {"username", "password"})

# No authentication (for development)
{:ok, driver} = Neo4jEx.start_link("bolt://localhost:7687")

# Custom timeouts
{:ok, driver} = Neo4jEx.start_link("bolt://localhost:7687",
  auth: {"neo4j", "password"},
  connection_timeout: 30_000,  # 30 seconds
  query_timeout: 60_000)       # 60 seconds
```

### Application Configuration

You can configure Neo4jEx in your application configuration:

```elixir
# config/config.exs
config :my_app, :neo4j,
  uri: "bolt://localhost:7687",
  auth: {"neo4j", "password"},
  connection_timeout: 15_000,
  query_timeout: 30_000
```

Then use it in your application:

```elixir
# In your application or supervisor
config = Application.get_env(:my_app, :neo4j)
{:ok, driver} = Neo4jEx.start_link(config[:uri],
  auth: config[:auth],
  connection_timeout: config[:connection_timeout],
  query_timeout: config[:query_timeout])
```

### Environment Variables

For development and testing, you can use environment variables:

```bash
export NEO4J_HOST=localhost
export NEO4J_PORT=7687
export NEO4J_USER=neo4j
export NEO4J_PASS=password
```

### Supervision Tree

#### Option 1: Using the Application Module (Recommended)

Configure drivers in your application config and let Neo4j.Application manage them:

```elixir
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

# lib/my_app/application.ex
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      # Other children...
      Neo4j.Application
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

Then use the named drivers:

```elixir
{:ok, results} = Neo4jEx.run(:default, "MATCH (n) RETURN count(n)")
{:ok, results} = Neo4jEx.run(:secondary, "MATCH (n) RETURN count(n)")
```

#### Option 2: Single Driver Configuration

For a single driver, you can configure it directly:

```elixir
# config/config.exs
config :neo4j_ex,
  uri: "bolt://localhost:7687",
  auth: {"neo4j", "password"}

# The Neo4j.Application will automatically start a :default driver
```

#### Option 3: Manual Driver Management

Start specific drivers manually in your supervision tree:

```elixir
# lib/my_app/application.ex
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      # Other children...
      {Neo4j.Driver, [
        "bolt://localhost:7687",
        [
          name: MyApp.Neo4j,
          auth: {"neo4j", "password"}
        ]
      ]}
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

Then use the named driver:

```elixir
{:ok, results} = Neo4jEx.run(MyApp.Neo4j, "MATCH (n) RETURN count(n)")
```

## Usage Examples

### Simple Queries

```elixir
# With implicit default driver (recommended)
{:ok, _} = Neo4jEx.run("""
  CREATE (alice:Person {name: "Alice", age: 30})
  CREATE (bob:Person {name: "Bob", age: 25})
  CREATE (alice)-[:KNOWS]->(bob)
""")

# Query with parameters using default driver
{:ok, results} = Neo4jEx.run(
  "MATCH (p:Person {name: $name}) RETURN p",
  %{name: "Alice"})

# Or with explicit driver
{:ok, _} = Neo4jEx.run(driver, """
  CREATE (alice:Person {name: "Alice", age: 30})
  CREATE (bob:Person {name: "Bob", age: 25})
  CREATE (alice)-[:KNOWS]->(bob)
""")

# Query with parameters and explicit driver
{:ok, results} = Neo4jEx.run(driver,
  "MATCH (p:Person {name: $name}) RETURN p",
  %{name: "Alice"})

# Process results
for record <- results.records do
  person = Neo4j.Result.Record.get(record, "p")
  IO.inspect(person)
end
```

### Multiple Named Drivers

```elixir
# Configure multiple drivers in config/config.exs
config :neo4j_ex,
  drivers: [
    default: [
      uri: "bolt://localhost:7687",
      auth: {"neo4j", "password"}
    ],
    analytics: [
      uri: "bolt://analytics-server:7687",
      auth: {"neo4j", "analytics_password"}
    ]
  ]

# Use different drivers for different purposes
{:ok, results} = Neo4jEx.run("MATCH (n:Person) RETURN count(n)")  # Uses :default
{:ok, results} = Neo4jEx.run(:analytics, "MATCH (n:Event) RETURN count(n)")  # Uses :analytics
```

### Working with Sessions

```elixir
result = Neo4jEx.session(driver, fn session ->
  # Multiple queries in the same session
  {:ok, _} = Neo4j.Session.run(session,
    "CREATE (p:Person {name: $name})", %{name: "Charlie"})

  {:ok, results} = Neo4j.Session.run(session,
    "MATCH (p:Person) RETURN count(p) AS total")

  # Return the count
  record = List.first(results.records)
  Neo4j.Result.Record.get(record, "total")
end)

IO.puts("Total persons: #{result}")
```

### Transactions

```elixir
# Automatic transaction management
result = Neo4jEx.transaction(driver, fn tx ->
  # All operations in this block are part of the same transaction
  {:ok, _} = Neo4j.Transaction.run(tx,
    "CREATE (p:Person {name: $name})", %{name: "David"})

  {:ok, _} = Neo4j.Transaction.run(tx,
    "CREATE (p:Person {name: $name})", %{name: "Eve"})

  # If this block completes successfully, transaction is committed
  # If an exception is raised, transaction is rolled back
  :success
end)
```

### Manual Transaction Control

```elixir
Neo4jEx.session(driver, fn session ->
  {:ok, tx} = Neo4j.Session.begin_transaction(session)

  try do
    {:ok, _} = Neo4j.Transaction.run(tx,
      "CREATE (p:Person {name: $name})", %{name: "Frank"})

    # Manually commit
    :ok = Neo4j.Transaction.commit(tx)
  rescue
    _error ->
      # Manually rollback on error
      :ok = Neo4j.Transaction.rollback(tx)
      reraise
  end
end)
```

### Working with Results

```elixir
{:ok, results} = Neo4jEx.run(driver, """
  MATCH (p:Person)-[:KNOWS]->(friend:Person)
  RETURN p.name AS person, friend.name AS friend, p.age AS age
""")

# Access by field name
for record <- results.records do
  person = Neo4j.Result.Record.get(record, "person")
  friend = Neo4j.Result.Record.get(record, "friend")
  age = Neo4j.Result.Record.get(record, "age")

  IO.puts("#{person} (#{age}) knows #{friend}")
end

# Access by index
for record <- results.records do
  person = Neo4j.Result.Record.get(record, 0)
  friend = Neo4j.Result.Record.get(record, 1)
  age = Neo4j.Result.Record.get(record, 2)

  IO.puts("#{person} (#{age}) knows #{friend}")
end

# Convert to map
for record <- results.records do
  map = Neo4j.Result.Record.to_map(record)
  IO.inspect(map)
  # %{"person" => "Alice", "friend" => "Bob", "age" => 30}
end

# Query statistics
summary = results.summary
if Neo4j.Result.Summary.contains_updates?(summary) do
  nodes_created = Neo4j.Result.Summary.get_counter(summary, "nodes_created")
  IO.puts("Created #{nodes_created} nodes")
end
```

### Streaming Large Result Sets

For large datasets, Neo4jEx provides a streaming interface that allows you to process results without loading everything into memory at once:

```elixir
# Stream all Person nodes without loading them all into memory
driver
|> Neo4jEx.stream("MATCH (n:Person) RETURN n")
|> Stream.each(&process_person/1)
|> Stream.run()

# Stream with custom batch size and timeout
driver
|> Neo4jEx.stream("MATCH (n:BigData) RETURN n", %{}, batch_size: 500, timeout: 60_000)
|> Stream.chunk_every(100)
|> Enum.each(&batch_process/1)

# Memory-efficient aggregation
total = driver
|> Neo4jEx.stream("MATCH (n:Transaction) RETURN n.amount")
|> Stream.map(fn record -> record |> Neo4j.Result.Record.get("n.amount") end)
|> Enum.sum()

# Stream with custom processing function
driver
|> Neo4jEx.Stream.run_with("MATCH (n:Person) RETURN n.name", %{}, 
   fn record -> 
     name = Neo4j.Result.Record.get(record, "n.name")
     String.upcase(name)
   end)
|> Enum.each(&IO.puts/1)
```

The streaming interface uses cursor-based pagination under the hood, automatically fetching data in batches to minimize memory usage while maintaining good performance.

### Connection Pooling

Neo4jEx provides efficient connection pooling for high-performance applications. Connection pooling allows you to reuse connections across multiple queries, reducing connection overhead and improving throughput.

#### Starting a Connection Pool

```elixir
# Start a connection pool
{:ok, _pool} = Neo4jEx.start_pool([
  uri: "bolt://localhost:7687",
  auth: {"neo4j", "password"},
  pool_size: 15,        # Maximum number of connections
  max_overflow: 5       # Additional connections when pool is full
])

# Or with a custom name
{:ok, _pool} = Neo4jEx.start_pool([
  uri: "bolt://localhost:7687",
  auth: {"neo4j", "password"},
  pool_size: 10,
  name: :my_pool
])
```

#### Using Pooled Connections

```elixir
# Execute queries using the default pool
{:ok, results} = Neo4jEx.Pool.run("MATCH (n:Person) RETURN n")

# Execute queries with parameters
{:ok, results} = Neo4jEx.Pool.run(
  "CREATE (p:Person {name: $name}) RETURN p", 
  %{name: "Alice"}
)

# Execute transactions using the pool
result = Neo4jEx.Pool.transaction(fn ->
  Neo4jEx.Pool.run("CREATE (p:Person {name: 'Bob'})")
  Neo4jEx.Pool.run("CREATE (p:Person {name: 'Carol'})")
  :success
end)

# Use a named pool
{:ok, results} = Neo4jEx.Pool.run(
  "MATCH (n) RETURN count(n)", 
  %{}, 
  pool_name: :my_pool
)
```

#### Pool Configuration Options

| Option          | Type        | Default | Description                           |
| --------------- | ----------- | ------- | ------------------------------------- |
| `:uri`          | `string()`  | -       | Neo4j connection URI (required)       |
| `:auth`         | `tuple()`   | `nil`   | Authentication credentials            |
| `:pool_size`    | `integer()` | `10`    | Maximum number of connections         |
| `:max_overflow` | `integer()` | `5`     | Additional connections when pool full |
| `:name`         | `atom()`    | -       | Pool name for multiple pools          |

#### Pool Management

```elixir
# Check pool status
status = Neo4jEx.Pool.status()
# Returns: {:ready, pool_size, checked_out, overflow}

# Stop a pool
Neo4jEx.stop_pool()

# Stop a named pool
Neo4jEx.stop_pool(:my_pool)
```

#### Benefits of Connection Pooling

- **Improved Performance**: Reuse existing connections instead of creating new ones
- **Resource Management**: Control the maximum number of concurrent connections
- **Scalability**: Handle high-concurrency scenarios efficiently
- **Automatic Recovery**: Connections are automatically recreated if they fail
- **Load Distribution**: Distribute queries across multiple connections

## Testing Your Connection

Use the included test script to verify your Neo4j connection:

```bash
# With default settings (localhost:7687, neo4j/password)
elixir scripts/test_connection.exs

# With custom settings
NEO4J_HOST=myhost NEO4J_PORT=7687 NEO4J_USER=myuser NEO4J_PASS=mypass elixir scripts/test_connection.exs
```

## Configuration Options

| Option                | Type                              | Default            | Description                |
| --------------------- | --------------------------------- | ------------------ | -------------------------- |
| `:auth`               | `{username, password}` or `map()` | `nil`              | Authentication credentials |
| `:user_agent`         | `string()`                        | `"neo4j_ex/0.1.0"` | Client identification      |
| `:connection_timeout` | `integer()`                       | `15_000`           | Connection timeout (ms)    |
| `:query_timeout`      | `integer()`                       | `30_000`           | Query timeout (ms)         |
| `:max_pool_size`      | `integer()`                       | `10`               | Max connections (future)   |

### Authentication Options

```elixir
# Tuple format (recommended)
auth: {"username", "password"}

# Map format (advanced)
auth: %{
  "scheme" => "basic",
  "principal" => "username",
  "credentials" => "password"
}

# No authentication
auth: nil
# or simply omit the :auth option
```

## Error Handling

```elixir
case Neo4jEx.run(driver, "INVALID CYPHER") do
  {:ok, results} ->
    # Handle success
    IO.puts("Query succeeded")

  {:error, {:query_failed, message}} ->
    # Handle query errors
    IO.puts("Query failed: #{message}")

  {:error, {:connection_failed, reason}} ->
    # Handle connection errors
    IO.puts("Connection failed: #{inspect(reason)}")

  {:error, reason} ->
    # Handle other errors
    IO.puts("Error: #{inspect(reason)}")
end
```

## Development

### Prerequisites

- Elixir 1.12+
- Neo4j 4.0+ or Memgraph running on localhost:7687

### Running Tests

```bash
# Run unit tests
mix test

# Run with a specific Neo4j instance
NEO4J_USER=neo4j NEO4J_PASS=yourpassword mix test

# Test connection
elixir scripts/test_connection.exs
```

### Architecture

The driver is built with a layered architecture:

```
Neo4jEx (Public API)
├── Neo4j.Driver (Driver Management)
├── Neo4j.Session (Session Management)
├── Neo4j.Transaction (Transaction Management)
├── Neo4j.Protocol.* (Bolt Protocol Implementation)
│   ├── Messages (Bolt Messages)
│   └── PackStream (Serialization)
├── Neo4j.Connection.* (Connection Layer)
│   ├── Socket (TCP Communication)
│   └── Handshake (Bolt Handshake)
└── Neo4j.Result.* & Neo4j.Types.* (Data Types)
    ├── Record (Query Results)
    ├── Summary (Query Metadata)
    └── Node, Relationship, Path (Graph Types)
```

## Roadmap

- [x] **Week 1**: Basic connection and Bolt handshake
- [x] **Week 2**: PackStream serialization and basic messaging
- [x] **Week 3**: Query execution and result parsing
- [x] **Week 4**: Polish, testing, and documentation
- [x] **v0.2.0**: Result streaming support for large datasets
- [x] **v0.3.0**: Connection pooling and improved performance
- [x] **v0.4.0**: Clustering support and routing
- [x] **v1.0.0**: Advanced Neo4j types (Point, Duration, etc.) and production readiness

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -am 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Neo4j team for the excellent Bolt protocol documentation
- Elixir community for the amazing ecosystem
- Contributors and testers who helped make this driver possible

## Support

- 📖 [Documentation](https://hexdocs.pm/neo4j_ex)
- 🐛 [Issue Tracker](https://github.com/Maxino22/neo4j_ex/issues)
- 💬 [Discussions](https://github.com/Maxino22/neo4j_ex/discussions)

---

Made with ❤️ for the Elixir and Neo4j communities.
