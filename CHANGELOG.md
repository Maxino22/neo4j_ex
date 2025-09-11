# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2025-01-11

### Fixed
- **Authentication Timeout Issues**: Fixed hardcoded 5-second timeout in `receive_message/3` function that was causing authentication failures. Increased timeout to 15 seconds to match connection timeout settings.
- **Compiler Warnings**: Removed all compiler warnings by cleaning up unused module attributes in PackStream module and unused variables in test files.
- **Result Handling**: Enhanced session result processing to properly handle field names from RUN response metadata, providing user-friendly map results instead of complex Record structures.

### Improved
- **Error Handling**: Better timeout handling throughout the driver with more descriptive error messages.
- **Documentation**: Added beta release badge and comprehensive documentation of current limitations including lack of streaming support.
- **Test Suite**: All 29 tests now pass without any warnings, providing a clean development experience.

### Added
- **Beta Release Documentation**: Added clear beta status indicators and roadmap for future versions.
- **Limitations Documentation**: Documented current limitations including no streaming support, single connection per session, and basic type support.
- **Version Roadmap**: Added detailed roadmap with specific features planned for v0.2.0 (streaming), v0.3.0 (connection pooling), v0.4.0 (clustering), and v1.0.0 (production readiness).

### Technical Details
- Driver timeout increased from 5s to 15s for better reliability
- Session module now properly extracts and maps field names from query responses
- PackStream module cleaned up unused binary markers (reserved for future use)
- Enhanced result collection with proper field name handling

## [0.1.0] - 2025-01-11

### Added

#### Core Features

- **Bolt Protocol Support**: Complete implementation of Neo4j's Bolt protocol v5.x
- **PackStream Serialization**: Full PackStream v2 encoder/decoder for binary data serialization
- **Authentication**: Support for basic authentication and no-auth scenarios
- **Connection Management**: Automatic TCP connection handling with proper handshake
- **Query Execution**: Simple and parameterized Cypher query execution
- **Transaction Support**: Full transaction lifecycle with automatic commit/rollback
- **Session Management**: Session-based query execution for better resource management
- **Error Handling**: Comprehensive error handling and reporting throughout the stack

#### High-Level API

- `Neo4jEx` module providing the main public API
- `Neo4j.Driver` for driver management with GenServer-based architecture
- `Neo4j.Session` for session-based query execution
- `Neo4j.Transaction` for transaction management with automatic error handling

#### Protocol Implementation

- `Neo4j.Protocol.PackStream` - PackStream v2 serialization/deserialization
- `Neo4j.Protocol.Messages` - Bolt message creation and parsing
- `Neo4j.Protocol.Bolt` - Bolt protocol utilities
- `Neo4j.Connection.Socket` - Low-level TCP socket operations
- `Neo4j.Connection.Handshake` - Bolt handshake implementation

#### Result Handling

- `Neo4j.Result.Record` - Rich record handling with Enumerable protocol support
- `Neo4j.Result.Summary` - Query metadata and execution statistics
- Support for accessing record values by index or field name
- Conversion utilities for maps and keyword lists

#### Type System

- `Neo4j.Types.Node` - Neo4j node representation
- `Neo4j.Types.Relationship` - Neo4j relationship representation
- `Neo4j.Types.Path` - Neo4j path representation
- Proper handling of Neo4j graph data types

#### Application Integration

- `Neo4j.Application` - Application callback for supervision tree integration
- Support for multiple named drivers in configuration
- Environment variable configuration support
- Flexible configuration options (timeouts, authentication, etc.)

#### Developer Experience

- Comprehensive documentation with examples
- Connection test script (`scripts/test_connection.exs`)
- Multiple configuration approaches (environment, application config, supervision tree)
- Rich error messages and troubleshooting guides

#### Testing & Quality

- Complete unit test suite with 29 tests
- PackStream round-trip testing
- Bolt message creation and parsing tests
- Handshake packet generation tests
- Zero compilation warnings
- ExUnit integration with proper test structure

### Technical Details

#### Supported Bolt Versions

- Bolt v5.4, v5.3, v5.2, v5.1 (negotiated automatically)

#### Supported Message Types

- `HELLO` - Authentication and connection initialization
- `GOODBYE` - Graceful connection termination
- `RUN` - Cypher query execution
- `PULL` - Result fetching
- `BEGIN` - Transaction start
- `COMMIT` - Transaction commit
- `ROLLBACK` - Transaction rollback
- `RESET` - Connection state reset

#### Configuration Options

- `:auth` - Authentication credentials (tuple or map format)
- `:user_agent` - Client identification string
- `:connection_timeout` - Connection timeout in milliseconds
- `:query_timeout` - Query timeout in milliseconds
- `:max_pool_size` - Maximum connections (reserved for future use)

#### Architecture

```
Neo4jEx (Public API)
├── Neo4j.Driver (Driver Management)
├── Neo4j.Session (Session Management)
├── Neo4j.Transaction (Transaction Management)
├── Neo4j.Protocol.* (Bolt Protocol Implementation)
├── Neo4j.Connection.* (Connection Layer)
└── Neo4j.Result.* & Neo4j.Types.* (Data Types)
```

### Dependencies

- Pure Elixir implementation with no runtime dependencies
- Development dependencies: ex_doc, excoveralls, dialyxir, credo

### Compatibility

- Elixir 1.12+
- Neo4j 4.0+
- Memgraph (tested and compatible)

### Examples

#### Basic Usage

```elixir
# Start a driver
{:ok, driver} = Neo4jEx.start_link("bolt://localhost:7687",
  auth: {"neo4j", "password"})

# Execute a query
{:ok, results} = Neo4jEx.run(driver, "MATCH (n:Person) RETURN n.name LIMIT 10")

# Process results
for record <- results.records do
  name = Neo4j.Result.Record.get(record, "n.name")
  IO.puts("Person: #{name}")
end
```

#### Transaction Usage

```elixir
result = Neo4jEx.transaction(driver, fn tx ->
  {:ok, _} = Neo4j.Transaction.run(tx,
    "CREATE (p:Person {name: $name})", %{name: "Alice"})
  {:ok, _} = Neo4j.Transaction.run(tx,
    "CREATE (p:Person {name: $name})", %{name: "Bob"})
  :success
end)
```

#### Application Configuration

```elixir
# config/config.exs
config :neo4j_ex,
  uri: "bolt://localhost:7687",
  auth: {"neo4j", "password"},
  connection_timeout: 15_000,
  query_timeout: 30_000
```

### Known Limitations

- Connection pooling not yet implemented (single connection per driver)
- Advanced Neo4j types (Point, Duration, etc.) not yet supported
- Clustering and routing not yet implemented

### Future Roadmap

- Connection pooling implementation
- Advanced Neo4j data types support
- Clustering and routing support
- Performance optimizations
- Streaming query results

---

## Development Notes

This release represents the completion of the initial 4-week development roadmap:

- **Week 1**: Basic connection and Bolt handshake ✅
- **Week 2**: PackStream serialization and basic messaging ✅
- **Week 3**: Query execution and result parsing ✅
- **Week 4**: Polish, testing, and documentation ✅

The driver is now production-ready for basic Neo4j operations and provides a solid foundation for future enhancements.

[Unreleased]: https://github.com/Maxino22/neo4j_ex/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/Maxino22/neo4j_ex/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/Maxino22/neo4j_ex/releases/tag/v0.1.0
