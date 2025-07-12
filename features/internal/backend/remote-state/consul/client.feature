# Metadata:
# Covers: internal/backend/remote-state/consul/client_test.go
# TestFunctions:
# - TestRemoteClient
# - TestRemoteClient_gzipUpgrade
# - TestConsul_largeState
# - TestConsul_stateLock
# - TestConsul_destroyLock
# - TestConsul_lostLock
# - TestConsul_lostLockConnection
# Note: TestRemoteClient_impl is a compile-time check.

Feature: Consul Remote State Client Operations
  This feature describes the behavior of the Consul client for remote state storage,
  including basic CRUD, GZIP handling, large state chunking, and robust locking.

  Background:
    Given a Consul test server is running
    And a Consul backend client is configured with address (Consul server address) and path "tf-test/myproject"

  Scenario: Basic State Operations with Consul Client (Path Variations)
    Given a Consul backend client configured for path "tf-test/path_A"
    When standard Get, Put, and Delete state operations are performed via this client
    Then these operations should succeed
    Given a Consul backend client configured for path "tf-test/path_B/" (with trailing slash)
    When standard Get, Put, and Delete state operations are performed via this client
    Then these operations should succeed

  Scenario: GZIP Compression Upgrade Path
    Given a Consul backend client "ClientNoGzip" configured for path "tf-test/gzip_test" with GZIP disabled
    And state "S1" is written using "ClientNoGzip"
    And a Consul backend client "ClientWithGzip" is configured for the same path "tf-test/gzip_test" but with GZIP enabled
    When state is read using "ClientWithGzip"
    Then the retrieved state should be "S1" (correctly read, possibly uncompressed if stored uncompressed)
    When new state "S2" is written using "ClientWithGzip"
    Then the data stored in Consul should be GZIP compressed
    And when state is read back using "ClientWithGzip"
    Then the retrieved state should be "S2" (correctly decompressed)

  Scenario Outline: Handling Large State Payloads with Chunking
    Given a Consul backend client configured for path "tf-test/large_state_test" with GZIP <GzipState>
    And a state payload of size <PayloadSizeDescription> (e.g., "slightly over 512KB", "small", "very large requiring multiple chunks with GZIP")
    When the state payload is written using the Put operation
    Then the operation should succeed
    And the data should be stored in Consul using <ExpectedChunkCount> chunk KVs plus a main pointer KV (or 1 KV if not chunked)
    And when the state is read back using the Get operation
    Then the retrieved data should match the original payload
    When a new, small state payload is written to the same path
    Then the old chunk KVs (if any) should be removed from Consul
    And only the new small payload should be stored (likely in a single KV)
    When the state is deleted
    Then all associated KVs (main pointer and any chunks) should be removed from Consul

    Examples:
      | GzipState | PayloadSizeDescription                            | ExpectedChunkCount |
      | disabled  | just over 512KB (e.g., 512KB + 2 bytes)           | 2                  | # 1 main pointer, 2 chunks
      | disabled  | just under 512KB but base64 > 512KB (e.g. 500KB)  | 1                  | # 1 main pointer, 1 chunk (due to base64 in transaction)
      | disabled  | small (e.g., 1KB)                                 | 0                  | # 1 main pointer, 0 chunks
      | enabled   | very large (e.g., 2MB raw, results in 3-4 chunks) | 4                  | # Example, actual depends on compression

  Scenario: State Locking and Unlocking with Consul Client (Concurrent Access)
    Given two Consul client instances "ClientA" and "ClientB" for the same state path
    When "ClientA" acquires a lock
    Then "ClientA" should hold the lock
    And when "ClientB" attempts to acquire the lock
    Then "ClientB" should fail to acquire it
    When "ClientA" releases the lock
    Then "ClientB" should be able to acquire the lock

  Scenario: Lock Key Cleanup and Force Unlock Behavior
    Given a Consul client "ClientA" for a state path
    When "ClientA" acquires a lock (ID "LockA")
    And "ClientA" releases lock "LockA"
    Then the lock key in Consul for that path should be removed
    When "ClientA" acquires a lock (ID "LockB")
    And another Consul client "ClientB" (for a different path or same) force-unlocks using lock ID "LockB"
    Then the lock key in Consul for that path should be removed
    And if "ClientA" attempts to release lock "LockB" again
    Then it should fail with a "consul lock was lost" error

  Scenario: Handling Lost Lock (External Deletion)
    Given a Consul client "ClientA" holds a lock on a state path
    And the lock's underlying KV entry in Consul is deleted externally (simulating session expiry/manual intervention)
    And the client's lock renewal mechanism detects this and attempts to re-establish the lock
    When "ClientA" eventually attempts to release its (original) lock
    Then the unlock operation should succeed (or not error catastrophically, as the lock was effectively gone)

  Scenario: Handling Lost Lock Due to Network Interruption
    Given a Consul client holds a lock, maintained by a session
    And network connectivity to Consul is temporarily lost and then restored multiple times
    And the Consul session renewal mechanism attempts to keep the session alive
    When the client eventually attempts to release its lock after connectivity is stable
    Then the unlock operation should succeed

```

Notes:
*   The "Large State Payloads" scenario is complex because the exact number of chunks depends on internal constants and base64 encoding for transactions. The BDD tries to capture the *concept* of chunking and cleanup.
*   Locking scenarios cover basic lock/unlock, force-unlock (simulated by unlocking with the same ID from another client instance which Consul's API allows for session takeover/destruction), and lost lock recovery.
*   The GZIP upgrade path ensures compatibility.

This completes processing `_test.go` files for `internal/backend/remote-state/consul/`.

Next, I will analyze the non-test `.go` files in `internal/backend/remote-state/consul/`:
*   `backend.go`
*   `backend_state.go`
*   `client.go`

I'll start with `backend.go` from this package.
