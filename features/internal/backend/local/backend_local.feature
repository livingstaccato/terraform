# Metadata:
# Covers: internal/backend/local/backend_local_test.go
# TestFunctions:
# - TestLocalRun
# - TestLocalRun_error
# - TestLocalRun_cloudPlan
# - TestLocalRun_stalePlan

Feature: Local Backend LocalRun Preparation
  This feature describes the behavior of the local backend's LocalRun method,
  which prepares the context for executing Terraform operations locally.
  It covers success scenarios, error handling, and state locking.

  Background:
    Given a local backend is initialized for testing
    And an empty configuration directory "testdata/empty" exists
    And an invalid configuration directory "testdata/invalid" exists
    And a basic configuration directory "testdata/apply" exists
    And a plan bookmark file "testdata/plan-bookmark/bookmark.json" exists

  Scenario: Successful LocalRun for a basic operation
    Given an operation for an empty configuration directory "testdata/empty"
    When the local backend's LocalRun method is called for the operation
    Then no error diagnostics should be produced
    And the backend state should be locked

  Scenario: LocalRun fails due to state refresh error
    Given an operation for an invalid configuration directory "testdata/invalid"
    And the backend's state manager is configured to fail on refresh
    When the local backend's LocalRun method is called for the operation
    Then error diagnostics should be produced
    And the backend state should be unlocked

  Scenario: LocalRun with a cloud plan bookmark
    Given an operation for configuration "testdata/apply"
    And the operation includes a plan file "testdata/plan-bookmark/bookmark.json" (cloud plan)
    When the local backend's LocalRun method is called for the operation
    Then error diagnostics should be produced (indicating cloud plans might not be fully supported for local execution preparation)
    And the backend state should be unlocked

  Scenario: LocalRun with a stale plan file
    Given an operation for configuration "testdata/apply"
    And a current state file exists with serial number 3
    And the operation includes a plan file which was created against state with serial number 2 (stale)
    When the local backend's LocalRun method is called for the operation
    Then error diagnostics should be produced indicating the plan is stale
    And the backend state should be unlocked

```

Notes for this Gherkin:
*   The `Background` sets up common test data paths.
*   "operation for an empty configuration directory" implies setting up `backendrun.Operation` with `ConfigDir`, `ConfigLoader`, etc.
*   The scenarios focus on the setup conditions and the key outcomes: presence/absence of diagnostics and the lock state of the backend.
*   The "cloud plan" scenario's expected outcome is based on the Go test expecting an error, implying that `LocalRun` may not fully process or might reject such plans for local re-planning/applying without further context.
*   The "stale plan" scenario describes the condition (state serial mismatch) and the expected failure.

This covers the core behaviors tested in `backend_local_test.go`.

Next, I'll process `internal/backend/local/backend_plan_test.go`.
