# Metadata:
# Covers: internal/backend/remote/backend_state_test.go
# TestFunctions:
# - TestRemoteClient_impl (compile-time check)
# - TestRemoteClient (uses generic remote.TestClient)
# - TestRemoteClient_stateLock (uses generic remote.TestRemoteLocks)
# - TestRemoteClient_Unlock_invalidID
# - TestRemoteClient_Unlock
# - TestRemoteClient_Put_withRunID

Feature: Remote Backend State Client Operations
  This feature describes the behavior of the remote backend's client for interacting
  with remote state storage, including basic CRUD, locking, and associating state with runs.
  It assumes interactions with a Terraform Cloud/Enterprise compatible API.

  Background:
    Given a remote backend initialized with a mock TFE client for workspace "default"

  Scenario: Basic State Operations (Get, Put, Delete via Generic Test Suite)
    Given a remote state client
    When standard Get, Put, and Delete state operations are performed
    Then these operations should succeed as per the defined remote client contract
      # This scenario represents the behavior tested by remote.TestClient

  Scenario: State Locking and Unlocking (via Generic Test Suite)
    Given two remote state client instances ("ClientA" and "ClientB") for the same state
    When "ClientA" locks the state
    And "ClientB" attempts to lock the same state
    Then "ClientB" should fail to acquire the lock
    When "ClientA" unlocks the state
    And "ClientB" attempts to lock the state again
    Then "ClientB" should successfully acquire the lock
      # This scenario represents the behavior tested by remote.TestRemoteLocks

  Scenario: Attempting to Unlock State with an Invalid Lock ID
    Given the remote state is locked by "UserA" with lock ID "LockID_A"
    When an attempt is made to unlock the state using an invalid lock ID "LockID_B"
    Then the unlock operation should fail
    And the error message should contain "does not match existing lock ID"

  Scenario: Successfully Unlocking State with a Valid Lock ID
    Given the remote state is locked with lock information (e.g., ID "test-lock-id", User "tester")
    When an attempt is made to unlock the state using the correct lock ID "test-lock-id"
    Then the unlock operation should succeed

  Scenario: Uploading State with TFE Run ID
    Given the environment variable "TFE_RUN_ID" is set to "run-example123"
    And a new Terraform state "S1" is prepared
    When the state "S1" is uploaded (Put) via the remote client
    Then the operation should succeed
    And the mock TFE client should verify that the uploaded state was associated with run ID "run-example123"

```

Notes:
*   The first two scenarios explicitly state that they represent behavior covered by generic test suites (`remote.TestClient`, `remote.TestRemoteLocks`). This avoids detailing every single Get/Put/Delete or lock contention case, assuming those suites are comprehensive.
*   The mock TFE client's role is implicit in the "Given" steps setting up the backend.
*   The `TestRemoteClient_Put_withRunID` scenario's verification step (`And the mock TFE client should verify...`) implies that the step definition will interact with the mock to check this condition, similar to how the Go test would.

This covers `backend_state_test.go`.

Next is `internal/backend/remote/backend_test.go`.
