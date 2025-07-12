# Metadata:
# Covers: internal/backend/remote-state/consul/backend_test.go
# TestFunctions:
# - TestBackend
# - TestBackend_lockDisabled
# - TestBackend_gzip
# Note: TestBackend_impl is a compile-time check.
# Note: Relies on generic backend.TestBackendStates, TestBackendStateLocks suites.

Feature: Consul Remote State Backend
  This feature describes the behavior of the Consul remote state backend,
  including configuration, state operations, locking, and GZIP compression.

  Background:
    Given a Consul server is available for testing
    And a base Consul backend configuration with:
      | address | (Consul server address) |
      | path    | "tf-test/myproject"     |

  Scenario Outline: Backend Configuration Validation and Defaults
    Given the Consul backend is configured with <ConfigurationDetail>
    When the backend configuration is prepared and then configured by Terraform
    Then the operation should <Outcome>
    And if it fails, the error message should contain "<ExpectedErrorMessagePart>"
    And if successful, the backend instance should reflect <ExpectedSetting>

    Examples:
      | ConfigurationDetail                                     | Outcome | ExpectedErrorMessagePart | ExpectedSetting                               |
      | missing 'path'                                          | fail    | "path" is required       |                                               |
      | no 'address' (uses default)                             | succeed |                          | address is "127.0.0.1:8500"                   |
      | no 'scheme' (uses default)                              | succeed |                          | scheme is "http"                              |
      | no 'lock' (uses default)                                | succeed |                          | locking is enabled                            |
      | no 'gzip' (uses default)                                | succeed |                          | GZIP is disabled                              |
      | 'lock' set to false                                     | succeed |                          | locking is disabled                           |
      | 'gzip' set to true                                      | succeed |                          | GZIP is enabled                               |
      | env CONSUL_CACERT="ca.pem", no ca_file in config        | succeed |                          | TLS CA file is "ca.pem"                       |
      | http_auth="user:pass"                                   | succeed |                          | HTTP basic auth is configured for "user"      |
      | http_auth="useronly"                                    | succeed |                          | HTTP basic auth is configured for "useronly"  |
      | invalid address "bad:address:format"                    | fail    | "invalid port"           |                                               | # Error from consulapi.NewClient

  Scenario: Basic State Operations with Consul Backend
    Given the Consul backend is configured as per background
    When I write a new Terraform state "S1" to the Consul backend
    Then the operation should succeed
    And when I read the state from the Consul backend
    Then the retrieved state should be equal to "S1"
    And when I list workspaces (states) using the configured path prefix
    Then the list should include "myproject" (or "default" if path is the full key)
    When I delete the state for workspace "default" (or key "tf-test/myproject")
    Then the operation should succeed
    And reading the state again should indicate it's not found or is empty

  Scenario: State Locking and Unlocking with Consul Backend
    Given the Consul backend is configured as per background
    And two Consul backend instances "B1" and "B2" are derived for the same state path "tf-test/myproject"
    And locking is enabled for both
    When "B1" acquires a lock on the state with lock info (ID "lock-B1", User "UserA")
    Then "B1" should successfully hold the lock
    And when "B2" attempts to acquire a lock on the same state
    Then "B2" should fail to acquire the lock due to it being held by "UserA"
    When "B1" releases its lock "lock-B1"
    Then the operation should succeed
    And when "B2" attempts to acquire a lock on the state again
    Then "B2" should successfully acquire the lock

  Scenario: State Operations with Locking Disabled
    Given two Consul backend instances "B1" and "B2"
    And "B1" is configured for state path "tf-test/path1" with locking disabled
    And "B2" is configured for state path "tf-test/path2" with locking disabled # Different paths to ensure no accidental shared lock
    When "B1" attempts to acquire a lock (which is a no-op)
    Then "B1" should report success (as locking is disabled)
    And when "B2" attempts to acquire a lock on its path (which is also a no-op)
    Then "B2" should report success
    And basic state operations (Put, Get) on "B1" should succeed

  Scenario: State Operations with GZIP Compression Enabled
    Given the Consul backend is configured with GZIP compression enabled
    And a new Terraform state "S_large" (which would benefit from compression)
    When I write state "S_large" to the Consul backend
    Then the operation should succeed
    And the data stored in Consul for the state should be GZIP compressed
    When I read the state from the Consul backend
    Then the retrieved state should be equal to "S_large" (correctly decompressed)

```

Notes:
*   The `Background` sets up the Consul server and basic backend config.
*   Scenarios cover basic state CRUD (implicitly via `TestBackendStates`), locking (implicitly via `TestBackendStateLocks`), disabled locking, and GZIP.
*   The GZIP scenario specifies that data *in Consul* should be compressed, implying an out-of-band check or mock behavior.
*   The "list workspaces" step is phrased to accommodate how Consul might simulate workspaces (often via KV path prefixes).

This covers `backend_test.go` for the Consul backend.

Next is `internal/backend/remote-state/consul/client_test.go`.
