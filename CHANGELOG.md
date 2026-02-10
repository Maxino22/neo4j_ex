# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- **Memgraph Compatibility**: Fixed version parsing bug that caused `{:error, :invalid_version_format}` when connecting to Memgraph databases
  - Issue: Version bytes `<<0, 0, 2, 5>>` from Memgraph were being incorrectly parsed as `{2, 5}` instead of `{5, 2}`
  - Root cause: The alternative version format parser had swapped major/minor version positions
  - Solution: Corrected variable names in `parse_version/1` to properly handle Memgraph's `<<0, 0, minor, major>>` format
  - Neo4j compatibility unaffected (uses different format `<<minor, 0, 0, major>>`)

### Improved

- **Documentation**: Major improvements to README for better developer experience
  - Added prominent "Understanding Auto-Start Behavior" section explaining automatic application startup
  - Clarified that neo4j_ex automatically starts when included as a dependency in Phoenix/Mix apps
  - Documented the "already started" error and how to avoid it
  - Added Memgraph compatibility to features list
  - Improved Quick Start section with clearer guidance for different use cases

### Added

- **Test Coverage**: Added comprehensive test cases for Memgraph version format parsing
  - Tests for Neo4j format: `<<minor, 0, 0, major>>`
  - Tests for Memgraph format: `<<0, 0, minor, major>>`
  - Tests for invalid version formats

## [0.1.4] - 2025-09-15

### Added

- Support for implicit `:default` driver across the public API.
  - `Neo4jEx.run/1`
  - `Neo4jEx.Session.start/0`
  - `Neo4jEx.Transaction.run/1`
- Users no longer need to pass `:default` explicitly:

  ```elixir
  # Before
  Neo4jEx.run(:default, "MATCH (n) RETURN n")

  # Now
  Neo4jEx.run("MATCH (n) RETURN n")
  ```

## [0.1.3] - 2025-09-12

### Fixed

- **External Application Integration**: Fixed critical child specification format issue that prevented neo4j_ex from working correctly when used as a dependency in external applications.
  - Changed child spec from `{Neo4j.Driver, {uri, opts}}` to `%{id: name, start: {Neo4j.Driver, :start_link, [uri, opts]}}`
  - This ensures the supervisor calls `start_link/2` with separate arguments instead of passing a tuple as the first argument
  - Resolves `Protocol.UndefinedError` when trying to convert tuple to string in `parse_uri/1`

### Added

- **Ecto-like Configuration**: Neo4j_Ex now provides the same clean, declarative configuration experience as Ecto
- **Comprehensive Integration Tests**: Added extensive test suite for external application integration scenarios
- **External Application Usage Guide**: Added detailed documentation (`EXTERNAL_APP_USAGE.md`) showing how to use neo4j_ex in external applications
- **Multiple Configuration Options**: Support for single driver, multiple drivers, and custom supervision tree configurations

### Improved

- **Application Startup**: More robust application startup with better error handling for missing configurations
- **Documentation**: Enhanced documentation with real-world usage examples and migration guides
- **Developer Experience**: Neo4j_Ex can now be used exactly like Ecto - just add to dependencies, configure, and use

### Technical Details

- Made `get_single_driver_config/0` and `build_driver_child_spec/2` public for testing
- Enhanced child specification building to use proper supervisor child spec format
- Added comprehensive test coverage for external app integration scenarios
- Fixed supervisor naming conflicts in tests

## [0.1.2-rc3] - 2025-09-12

### Fixed

- Application config fixes

## [0.1.2-rc2] - 2025-09-12

### Added

- Support for **advanced Neo4j data types** (datetime, temporal and spatial).
- **Streaming query results** for efficient handling of large datasets.
- **Connection pooling** for better concurrency and resource management.

## [0.1.2-rc1] - 2025-0-11

### Fixed

- **Message Buffering Issues**: Fixed critical bug where multiple Bolt protocol messages arriving in a single network packet were not properly handled, causing timeouts in both session queries and transactions. Implemented proper message buffering system using process dictionary to maintain unprocessed data between message receives.
- **Transaction Result Handling**: Fixed transaction result format to properly wrap results in `{:ok, result}` tuples for successful transactions, matching expected API contract.
- **Session and Transaction Compatibility**: Both session and transaction modules now properly handle the Bolt protocol's message sequencing, resolving timeout issues that prevented successful query execution.

### Improved

- **Robust Message Processing**: Enhanced message handling to properly process all messages in network packets, not just the first one, ensuring reliable communication with Neo4j server.
- **Resource Management**: Added proper cleanup of message buffers when operations complete or fail, preventing memory leaks.

### Technical Details

- Implemented message buffering system in `Neo4j.Session` and `Neo4j.Transaction` modules
- Modified `receive_message/3` functions to maintain per-socket message buffers using `:erlang.get/1` and `:erlang.put/2`
- Enhanced message decoding to properly handle remaining data after successful message parsing
- Fixed transaction result wrapping to return `{:ok, result}` format
- Updated result structures to use proper `Neo4j.Result.Record` and `Neo4j.Result.Summary` structs

## [0.1.1] - 2025-09-11

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

## [0.1.0] - 2025-09-11

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
