# Source Go File: internal/backend/local/backend_apply.go
# Source Go Test: internal/backend/local/backend_apply_test.go

Feature: Local Backend Apply Operation
  This feature describes the apply operation for the local backend, focusing on
  how it interacts with providers, handles plans, and manages state. Cty.Value
  is used for resource states and provider configurations.

  Background:
    Given a local backend initialized for testing
    And a mock "test" provider configured for the backend

  Scenario: Basic apply operation creating a resource
    Given the "test" provider's ApplyResourceChangeFn is configured to return a new state:
      cty.ObjectVal({"id": "yes", "ami": "bar"})
    And an apply operation is prepared for configuration in "./testdata/apply"
    When the backend performs the apply operation
    Then the operation result should be OperationSuccess
    And the provider's PlanResourceChangeFn should have been called
    And the provider's ApplyResourceChangeFn should have been called
    And the final state should contain "test_instance.foo" with attributes {"id":"yes", "ami":"bar"}
    And no error output should be produced

  Scenario: Apply operation with a check block
    Given the "test" provider's ApplyResourceChangeFn is configured to return a new state:
      cty.ObjectVal({"id": "yes", "ami": "bar"})
    And an apply operation is prepared for configuration in "./testdata/apply-check"
    When the backend performs the apply operation
    Then the operation result should be OperationSuccess
    And the provider's ApplyResourceChangeFn should have been called
    And the standard output should not contain "Check block assertion known after apply"

  Scenario: Apply operation on an empty configuration directory (non-destroy)
    Given an apply operation is prepared for an empty configuration in "./testdata/empty"
    When the backend performs the apply operation
    Then the operation result should not be OperationSuccess
    And the provider's ApplyResourceChangeFn should not have been called
    And the state output file should not exist
    And the error output should contain "Error: No configuration files"

  Scenario: Apply operation on an empty configuration directory (destroy mode)
    Given an apply operation is prepared for an empty configuration in "./testdata/empty" with DestroyMode true
    When the backend performs the apply operation
    Then the operation result should be OperationSuccess
    And the provider's ApplyResourceChangeFn should not have been called
    And the final state should be "<no state>" (empty)

  Scenario: Apply operation with a provider error during resource application
    Given the "test" provider's ApplyResourceChangeFn is configured to:
      - Return cty.ObjectVal({"id":"foo", "ami":"bar"}) for "test_instance.foo"
      - Return an error "ami error" for "test_instance.bar" (which has ami="error" in config)
    And an apply operation is prepared for configuration in "./testdata/apply-error"
    When the backend performs the apply operation
    Then the operation result should not be OperationSuccess
    And the final state should contain "test_instance.foo" with attributes {"id":"foo", "ami":"bar"}
    And the error output should contain "Error: ami error"

  Scenario: Apply operation with backend state writing failure
    Given the "test" provider's ApplyResourceChangeFn returns a successful new state
    And the backend's StateMgr is configured to fail on WriteState with "fake failure"
    And an apply operation is prepared for configuration in "./testdata/apply"
    When the backend performs the apply operation
    Then the operation result should not be OperationSuccess
    And the error output should contain "Error saving state: fake failure"
    And a fallback state file "errored.tfstate" should be created containing the tainted resource

  Scenario: Apply operation with refresh explicitly disabled (via plan)
    Given a prior state exists for "./testdata/plan"
    And an apply operation is prepared using a plan where refresh was false
    When the backend performs the apply operation
    Then the provider's ReadResourceFn should not have been called

  Scenario: Apply operation canceled during provider execution
    Given the "test" provider's ApplyResourceChangeFn will trigger a context cancellation
    And an auto-approved apply operation is prepared for configuration in "./testdata/apply"
    When the backend performs the apply operation with a cancellable context
    Then the operation result should not be OperationSuccess
    And the error output should contain "execution halted"

  # Note:
  # - cty.Value is used for:
  #   - Mock provider's ApplyResourceChangeResponse.NewState.
  #   - Verifying resource attributes in the final states.State.
  # - Schema definitions (applyFixtureSchema, planFixtureSchema) use cty.Type.
  # - testOperationApply sets up backendrun.Operation which includes configurations and state.
  # - This BDD focuses on the local backend's orchestration of the apply graph and state persistence,
  #   and how it uses cty.Value in these processes.
  # - Details of graph building and actual provider calls are abstracted but their cty-related inputs/outputs are key.
  # - "applyFixtureSchema" and similar imply a specific configschema.Block for the provider.
  # - State checking often involves comparing string output of the state, which reflects underlying cty.Values.
