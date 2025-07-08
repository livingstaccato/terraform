# Source Go File: internal/backend/local/backend_local.go
# Source Go Test: internal/backend/local/backend_local_test.go

Feature: Local Backend Run Execution
  This feature describes the execution flow of the `LocalRun` method in the
  local backend. It covers how the backend handles different operation types
  (though tests primarily focus on apply-like flows), state locking, and
  error conditions like stale plans or configuration issues.

  Background:
    Given a local backend initialized for testing with a state path
    And a Terraform configuration directory (e.g., "./testdata/empty" or "./testdata/apply")
    And a configuration loader for that directory
    And necessary UI views and state locker

  Scenario: Successful LocalRun execution (e.g., for an apply-like operation)
    Given a backendrun.Operation for an apply-like flow with a valid configuration
    When LocalRun is called on the backend with this operation
    Then no diagnostics with errors should be produced
    And the backend state should be locked after the run

  Scenario: LocalRun execution with an error during state refresh
    Given the backend's StateMgr is configured to fail on RefreshState (e.g., "intentionally failing")
    And a backendrun.Operation for a flow that involves state refresh
    When LocalRun is called on the backend with this operation
    Then diagnostics with errors should be produced
    And the backend state should be unlocked after the run

  Scenario: LocalRun execution with a cloud plan (not supported by local backend)
    Given a backendrun.Operation for an apply-like flow
    And the operation includes a PlanFile that represents a cloud plan (e.g., from "./testdata/plan-bookmark/bookmark.json")
    When LocalRun is called on the backend with this operation
    Then diagnostics with errors should be produced (indicating incompatibility or error processing such a plan)
    And the backend state should be unlocked after the run

  Scenario: LocalRun execution with a stale plan
    Given the current state file has a serial number (e.g., 3)
    And a backendrun.Operation for an apply-like flow is provided
    And the operation's PlanFile has a prior state with a lower serial number (e.g., 2)
    When LocalRun is called on the backend with this operation
    Then diagnostics with errors should be produced indicating the plan is stale
    And the backend state should be unlocked after the run

  # Note:
  # - The cty.Value aspects are primarily in how the backend configuration (cty.ObjectVal) and
  #   state (which involves cty.Value for resources) are handled internally by the
  #   components that LocalRun orchestrates (like Context.Plan, Context.Apply).
  # - This BDD focuses on the LocalRun method's control flow and error handling related to
  #   plan files, state staleness, and internal operation errors.
  # - `testOperationApply` in the Go tests sets up a backendrun.Operation.
  # - `assertBackendStateLocked` and `assertBackendStateUnlocked` check the lock status.
  # - Specific details of plan content or state content are handled by tests for Plan/Apply.
  # - The "cloud plan" test implies that LocalRun will attempt to process the plan and fail due to its nature.
  # - "Stale plan" means the state on disk is newer than the state the plan was based on.
  # - The actual operations (plan, apply, refresh) within LocalRun are delegated to the Context,
  #   so this BDD doesn't re-test the details of those operations themselves but rather LocalRun's orchestration.
