# Source Go File: internal/backend/local/backend_plan.go
# Source Go Test: internal/backend/local/backend_plan_test.go

Feature: Local Backend Plan Operation
  This feature describes the plan operation for the local backend. It covers
  how the backend interacts with providers to generate an execution plan,
  handles existing state, refresh behavior, and various plan modes like Normal
  and Destroy. Cty.Value is used for resource configurations, state, and provider schemas.

  Background:
    Given a local backend initialized for testing
    And a mock "test" provider configured for the backend with a defined schema

  Scenario: Basic plan operation creating a new resource
    Given the "test" provider's PlanResourceChangeFn is configured for standard diffing
    And a plan operation is prepared for configuration in "./testdata/plan" with refresh enabled
    When the backend performs the plan operation
    Then the operation result should be OperationSuccess
    And the provider's PlanResourceChangeFn should have been called
    And the backend state should be unlocked after the run
    And no error output should be produced

  Scenario: Plan operation when "in automation" (affecting UI output)
    Given a plan operation is prepared for configuration in "./testdata/plan" with refresh enabled
    And the operation is not marked as "in automation" (e.g., View is for human)
    When the backend performs the plan operation
    Then the standard output should contain "You didn't use the -out option"
    # This test implicitly verifies that certain UI messages are present/absent based on automation context,
    # which is handled by the view passed to the operation.

  Scenario: Plan operation on an empty configuration directory
    Given a plan operation is prepared for an empty configuration in "./testdata/empty" with refresh enabled
    When the backend performs the plan operation
    Then the operation result should not be OperationSuccess
    And the error output should contain "No configuration files"
    And the backend state should be unlocked after the run

  Scenario: Plan operation with a context error (e.g., invalid parallelism)
    Given the backend's ContextOpts are set to cause an error during context creation (e.g., parallelism = -1)
    And a plan operation is prepared for configuration in "./testdata/plan"
    When the backend performs the plan operation
    Then the operation result should be OperationFailure
    And the error output should contain "Invalid parallelism value"
    And the backend state should be unlocked after the run

  Scenario: Plan operation showing changes to outputs
    Given an existing state with outputs: {"changed":"before", "sensitive_before":"before" (sensitive), "sensitive_after":"before", "removed":"before", "unchanged":"before"}
    And a plan operation is prepared for configuration in "./testdata/plan-outputs-changed" which will:
      - Add output "added" = "after"
      - Change output "changed" to "after"
      - Change output "sensitive_after" to "after" (and mark sensitive)
      - Mark "sensitive_before" as sensitive (value unchanged)
      - Remove output "removed"
      - Keep output "unchanged" as "before"
    And the plan is to be saved to an output path
    When the backend performs the plan operation with refresh enabled
    Then the operation result should be OperationSuccess
    And the plan should not be considered empty
    And the standard output should show changes to outputs:
      | Action | Name             | OldValue          | NewValue          | Sensitive |
      | +      | added            |                   | "after"           | false     |
      | ~      | changed          | "before"          | "after"           | false     |
      | -      | removed          | "before"          | null              | false     |
      | ~      | sensitive_after  | (sensitive value) | (sensitive value) | true      | # Value becomes sensitive
      | ~      | sensitive_before | (sensitive value) | (sensitive value) | true      | # Value remains sensitive

  Scenario: Plan operation with only module output changes (should render as no-op)
    Given an existing state with a module "mod" output "mod.changed" = "before"
    And a plan operation is prepared for configuration in "./testdata/plan-module-outputs-changed" which changes "mod.changed" to "after"
    And the plan is to be saved to an output path
    When the backend performs the plan operation with refresh enabled
    Then the operation result should be OperationSuccess
    And the plan should be considered empty (as only non-root module outputs changed)
    And the standard output should contain "No changes. Your infrastructure matches the configuration."

  Scenario: Plan operation with a tainted resource
    Given an existing state where "test_instance.foo" is tainted
    And a plan operation is prepared for configuration in "./testdata/plan" with refresh enabled
    And the plan is to be saved to an output path
    When the backend performs the plan operation
    Then the operation result should be OperationSuccess
    And the provider's ReadResourceFn should have been called (due to refresh)
    And the plan should not be empty
    And the standard output should indicate "test_instance.foo" is tainted and will be replaced (-/+)

  Scenario: Plan operation with a create-before-destroy tainted resource
    Given an existing state where "test_instance.foo" is tainted
    And a plan operation is prepared for configuration in "./testdata/plan-cbd" (which uses create_before_destroy)
    And the plan is to be saved to an output path
    When the backend performs the plan operation with refresh enabled
    Then the operation result should be OperationSuccess
    And the standard output should indicate "test_instance.foo" is tainted and will be replaced (+/-)

  Scenario: Plan operation with refresh explicitly disabled
    Given an existing state for "./testdata/plan"
    And a plan operation is prepared for configuration in "./testdata/plan" with refresh disabled
    When the backend performs the plan operation
    Then the operation result should be OperationSuccess
    And the provider's ReadResourceFn should not have been called
    And the plan should be empty (assuming config matches state)

  Scenario: Plan operation in Destroy mode
    Given an existing state for "./testdata/plan"
    And a plan operation is prepared for configuration in "./testdata/plan" with DestroyMode true and refresh enabled
    And the plan is to be saved to an output path
    When the backend performs the plan operation
    Then the operation result should be OperationSuccess
    And the plan should not be empty
    And the saved plan file should show all resources marked for Delete

  Scenario: Plan operation in Destroy mode with data sources
    Given an existing state for "./testdata/destroy-with-ds" (includes managed and data resources)
    And a plan operation is prepared for configuration in "./testdata/destroy-with-ds" with DestroyMode true and refresh enabled
    And the plan is to be saved to an output path
    When the backend performs the plan operation
    Then the operation result should be OperationSuccess
    And the plan should not be empty
    And the saved plan file should show the managed resource for Delete and the data source for Read (or NoOp if not refreshed by plan)
    And the standard output should only show the managed resource for destruction

  Scenario: Plan operation with an output path and no changes
    Given an existing state for "./testdata/plan" that matches the configuration
    And a plan operation is prepared for configuration in "./testdata/plan" with refresh enabled
    And the plan is to be saved to an output path "plan.tfplan"
    When the backend performs the plan operation
    Then the operation result should be OperationSuccess
    And the saved "plan.tfplan" should reflect an empty set of changes

  Scenario: Plan operation with invalid options (e.g., RefreshOnly with ForceReplace)
    Given a plan operation is prepared with conflicting options: RefreshOnlyMode true and ForceReplace for "test_instance.foo"
    When the backend performs the plan operation
    Then the operation result should not be OperationSuccess
    And an error output should be produced indicating the conflict

  # Note:
  # - cty.Value is used for:
  #   - Representing state (prior state, resource attributes).
  #   - Representing configuration values (though often abstracted by config loader).
  #   - Provider schemas (configschema.Block using cty.Type).
  #   - Plan changes (ResourceInstanceChangeSrc.Before, .After).
  # - `testOperationPlan` sets up backendrun.Operation.
  # - `planFixtureSchema` defines a mock provider schema.
  # - `testPlanState()` creates a sample states.State.
  # - This BDD focuses on the local backend's orchestration of the plan generation,
  #   how it uses cty.Value in this process, and how it handles various flags and modes.
