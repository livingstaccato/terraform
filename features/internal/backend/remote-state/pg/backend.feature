# Metadata:
# Covers: internal/backend/remote-state/pg/backend_test.go
# TestFunctions:
# - TestBackendConfig
# - TestBackendConfigSkipOptions
# - TestBackendStates
# - TestBackendStateLocks
# - TestBackendConcurrentLock
# Note: TestBackend_impl is a compile-time check.

Feature: PostgreSQL (pg) Remote State Backend
  This feature describes the behavior of the PostgreSQL (pg) remote state backend,
  including configuration, schema/table/index creation options, state operations, and locking.

  Background:
    Given a PostgreSQL server is available and accessible via DATABASE_URL environment variable
    And the target database (e.g., "terraform_backend_pg_test") exists

  Scenario Outline: PostgreSQL Backend Configuration and Connection
    Given the PostgreSQL backend is configured with <ConfigurationDetail>
    And relevant environment variables are <EnvVarState>
    When the backend configuration is prepared and then configured by Terraform
    Then the operation should <Outcome>
    And if it fails, the error message should contain "<ExpectedErrorMessagePart>"
    And if successful, a database connection should be established
    And a schema named "<SchemaName>" (or derived) should exist with a state table

    Examples:
      | ConfigurationDetail                                      | EnvVarState                                       | Outcome | ExpectedErrorMessagePart         | SchemaName                      |
      | conn_str=(DATABASE_URL), schema_name="test_schema1"      |                                                   | succeed |                                  | test_schema1                    |
      | schema_name="test_schema2" (conn_str uses PG env vars)   | PGDATABASE=(db_name), PGSSLMODE="disable"         | succeed |                                  | test_schema2                    |
      | schema_name="test_schema3" (conn_str from PG_CONN_STR)   | PG_CONN_STR=(DATABASE_URL)                        | succeed |                                  | test_schema3                    |
      | conn_str=(DATABASE_URL), schema_name="test_schema4"      | PGUSER="bad", PGPASSWORD="bad"                    | fail    | "password authentication failed" | test_schema4                    |
      | schema_name="test_schema5"                               | PGHOST="nonexistent"                              | fail    | "no such host"                   | test_schema5                    |
      | schema_name="test_schema6", skip_schema_creation="foo"   | PGDATABASE=(db_name), PGSSLMODE="disable"         | fail    | "invalid value for \"skip_schema_creation\"" | test_schema6    |
      | no schema_name (uses default)                            | PGDATABASE=(db_name), PGSSLMODE="disable"         | succeed |                                  | terraform_remote_state          |
      | conn_str="bad_conn_str_format"                           |                                                   | fail    | "cannot parse conn_str"          | (any)                           |
      | conn_str=(good_format_bad_db), schema_name="s"           |                                                   | fail    | "database \"bad_db\" does not exist" | s                             | # DB connection error
      | conn_str=(good_db_bad_perms), schema_name="s"            |                                                   | fail    | "permission denied to create schema" | s                             | # DB setup error

  Scenario Outline: Schema, Table, and Index Creation Skip Options
    Given a PostgreSQL connection string (DATABASE_URL)
    And a unique schema name for the test (e.g., "test_skip_opts_schema")
    And the backend is configured with schema_name, and skip_schema_creation=<SkipSchema>, skip_table_creation=<SkipTable>, skip_index_creation=<SkipIndex>
    And <Prerequisites> are manually set up in the database for the schema
    When the backend is configured by Terraform
    Then the operation should succeed
    And the schema should exist
    And the state table within that schema should exist
    And the unique index on the 'name' column of the state table should <IndexExistence>

    Examples:
      | SkipSchema | SkipTable | SkipIndex | Prerequisites                                     | IndexExistence | Description                                     |
      | false      | false     | false     | Schema, Table, Index do NOT exist initially       | exist          | Default: all created by Terraform               |
      | true       | false     | false     | Schema created manually                           | exist          | Skip schema creation                            |
      | false      | true      | false     | Schema and Table created manually                 | exist          | Skip table creation                             |
      | false      | false     | true      | Schema, Table, and Index created manually         | exist          | Skip index creation (index pre-exists)          |
      | false      | false     | true      | Schema and Table created manually (no index yet)  | not exist      | Skip index creation (index not created by TF)   |

  Scenario: Automatic State Row Initialization for New Workspace in PostgreSQL
    Given the PostgreSQL backend is configured with conn_str=(DATABASE_URL) and schema_name="pg_auto_init_schema"
    And the schema "pg_auto_init_schema" and state table are initialized (but empty for new workspace)
    And workspace "new_pg_ws" does not yet have a row in the state table
    When the state manager is requested for workspace "new_pg_ws"
    Then the operation should succeed
    And a row for "new_pg_ws" containing an empty Terraform state should be created in the state table
    And this initialization should have involved a lock and unlock operation

  Scenario: Core State Operations with PostgreSQL Backend
    Given the PostgreSQL backend is configured with conn_str=(DATABASE_URL) and schema_name="pg_state_ops_schema"
    And the schema "pg_state_ops_schema" and state table are initialized
    When I write a new Terraform state "S1" to the backend for workspace "default"
    Then the operation should succeed
    And when I read the state from the backend for workspace "default"
    Then the retrieved state should be equal to "S1"
    And when I list workspaces (states)
    Then the list should include "default"
    When I delete the state for workspace "another_ws" (after creating it)
    Then the operation should succeed

  Scenario: State Locking and Unlocking with PostgreSQL Backend
    Given the PostgreSQL backend is configured with conn_str=(DATABASE_URL) and schema_name="pg_lock_schema"
    And the schema "pg_lock_schema" and state table are initialized
    And two PostgreSQL backend instances "B1" and "B2" use this configuration
    When "B1" acquires a lock on the "default" workspace state
    Then "B1" should successfully hold the lock (a row is inserted into the "<SchemaName>.terraform_locks" table)
    And when "B2" attempts to acquire a lock on the "default" workspace state
    Then "B2" should fail to acquire the lock
    When "B1" releases its lock
    Then the operation should succeed (the row is deleted from the "<SchemaName>.terraform_locks" table)
    And when "B2" attempts to acquire a lock on the "default" workspace state again
    Then "B2" should successfully acquire the lock

  Scenario: Concurrent Locking on Different Schemas (Workspaces)
    Given PostgreSQL connection string (DATABASE_URL)
    And backend instance "B_Schema1" is configured for schema_name="concurrent_schema1"
    And backend instance "B_Schema2" is configured for schema_name="concurrent_schema2"
    And schemas "concurrent_schema1" and "concurrent_schema2" with state tables are initialized
    When "B_Schema1" acquires a lock for its "default" workspace
    Then "B_Schema1" should successfully hold the lock
    And when "B_Schema2" acquires a lock for its "default" workspace
    Then "B_Schema2" should also successfully hold the lock (as they are different schemas/states)

```

Notes:
*   The BDD abstracts the direct SQL queries used in tests for setup/cleanup.
*   `(DATABASE_URL)` and `(db_name)` are placeholders for actual connection details.
*   The "Skip Options" scenario details how flags affect schema/table/index creation and what prerequisites are needed.
*   Locking mechanism for PG is abstracted (row in state table or separate lock table).

This covers `backend_test.go` for the PG backend.

Next is `internal/backend/remote-state/pg/client_test.go`.
