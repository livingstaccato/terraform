# Metadata:
# Covers: internal/backend/remote-state/inmem/backend_test.go
# TestFunctions:
# - TestBackendConfig
# - TestBackend
# - TestBackendLocked
# - TestRemoteState
# Note: TestBackend_impl is a compile-time check. TestMain is test runner setup.

Feature: In-Memory (inmem) Remote State Backend
  This feature describes the behavior of the in-memory (inmem) remote state backend,
  which is primarily used for testing. It covers configuration, state operations, and locking.

  Background:
    Given the in-memory backend system is reset
    And an in-memory backend instance "B1" is configured

  Scenario: Basic State Operations with In-Memory Backend
    When I write a new Terraform state "S1" to backend "B1" for workspace "default"
    Then the operation should succeed
    And when I read the state from backend "B1" for workspace "default"
    Then the retrieved state should be equal to "S1"
    And when I list workspaces for backend "B1"
    Then the list should include "default"
    When I create a new workspace "test_ws" via backend "B1" (by requesting its StateMgr and writing state)
    Then the list of workspaces for backend "B1" should include "default" and "test_ws"
    When I delete the state for workspace "test_ws" from backend "B1"
    Then the operation should succeed
    And reading the state again for "test_ws" from backend "B1" should indicate it's not found or is empty

  Scenario: State Locking and Unlocking with In-Memory Backend
    Given an in-memory backend instance "B_Lock_1" is configured
    And another in-memory backend instance "B_Lock_2" is configured (representing a concurrent process)
    When "B_Lock_1" acquires a lock on the "default" workspace state with lock info (ID "LID_1", User "UserA")
    Then "B_Lock_1" should successfully hold the lock
    And when "B_Lock_2" attempts to acquire a lock on the "default" workspace state
    Then "B_Lock_2" should fail to acquire the lock
    When "B_Lock_1" releases its lock "LID_1"
    Then the operation should succeed
    And when "B_Lock_2" attempts to acquire a lock on the "default" workspace state again
    Then "B_Lock_2" should successfully acquire the lock

  Scenario: Configuring and Using a Pre-existing Lock ID
    Given the in-memory backend system is reset
    And an in-memory backend instance "B_PreLock" is configured with a 'lock_id' "pre_existing_lock_id"
    When the state manager for the "default" workspace is retrieved from "B_PreLock"
    Then the "default" workspace should be considered locked with "pre_existing_lock_id" by the backend
    And an attempt to unlock the "default" workspace with lock ID "pre_existing_lock_id" should succeed

  Scenario: Automatic Empty State Initialization for New In-Memory Workspace
    Given the in-memory backend system is reset
    And an in-memory backend instance "B_Init" is configured
    And workspace "new_empty_ws" does not yet exist in the in-memory store
    When the state manager for workspace "new_empty_ws" is requested from "B_Init"
    Then the operation should succeed
    And an empty Terraform state should now exist for "new_empty_ws" in the in-memory store
    And this initialization should have involved a lock and unlock operation

  Scenario: Interaction with remote.State Wrapper
    Given an in-memory backend instance "B_RemoteTest" is configured
    When a state manager for workspace "w_remote" is obtained from "B_RemoteTest"
    And a new empty Terraform state "S_empty" is written via the state manager
    And the state is persisted via the state manager
    And the state is refreshed via the state manager
    Then all operations (write, persist, refresh) should succeed
    And the state held by the state manager should be "S_empty"

```

Notes:
*   The `Background` includes resetting the in-memory backend, crucial due to its global state nature in tests.
*   The scenario "Configuring and Using a Pre-existing Lock ID" attempts to capture the essence of `TestBackendConfig`. The step `Then the "default" workspace should be considered locked...` would need a way to verify this, perhaps by another instance failing to lock it, or by checking internal state if the BDD framework allows. The test itself checks by being able to unlock it.
*   The "Interaction with remote.State Wrapper" covers `TestRemoteState`.

This covers `backend_test.go` for the `inmem` backend.

Next is `internal/backend/remote-state/inmem/client_test.go`.
