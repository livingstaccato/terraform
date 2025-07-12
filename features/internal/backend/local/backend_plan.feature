# Metadata:
# Covers: internal/backend/local/backend_plan_test.go
# TestFunctions:
# - TestLocal_planBasic
# - TestLocal_planInAutomation
# - TestLocal_planNoConfig
# - TestLocal_plan_context_error
# - TestLocal_planOutputsChanged
# - TestLocal_planModuleOutputsChanged
# - TestLocal_planTainted
# - TestLocal_planDeposedOnly
# - TestLocal_planTainted_createBeforeDestroy
# - TestLocal_planRefreshFalse
# - TestLocal_planDestroy
# - TestLocal_planDestroy_withDataSources
# - TestLocal_planOutPathNoChange
# - TestLocal_invalidOptions

Feature: Local Backend Plan Operation
  This feature describes the behavior of the 'plan' operation when using the local backend,
  covering various scenarios including refreshes, output changes, tainted resources,
  destroy plans, and error handling.

  Background:
    Given a local backend is initialized for testing
    And a mock "test" provider is configured with a basic schema for "test_instance" and "test_ds"

  Scenario: Basic Plan Operation with Refresh
    Given the configuration in "testdata/plan"
    When a Terraform plan operation is run with refresh enabled
    Then the operation should be successful
    And the provider's PlanResourceChange method should have been called
    And the backend state lock should be released
    And there should be no error output

  Scenario: Plan Operation UI Message when Not in Automation Mode
    Given the configuration in "testdata/plan"
    And Terraform is NOT running in automation mode
    When a Terraform plan operation is run with refresh enabled
    Then the operation should be successful
    And the standard output should contain "You didn't use the -out option"

  Scenario: Plan Operation on an Empty Configuration Directory
    Given the configuration in "testdata/empty" (which is an empty directory)
    When a Terraform plan operation is run with refresh enabled
    Then the operation should fail
    And the error output should contain "No configuration files"
    And the backend state lock should be released

  Scenario: Plan Operation with Context Initialization Error
    Given the configuration in "testdata/plan"
    And Terraform context initialization is configured to fail with "Invalid parallelism value"
    When a Terraform plan operation is run
    Then the operation should fail
    And the error output should contain "Error: Invalid parallelism value"
    And the backend state lock should be released

  Scenario: Plan Reflects Changes to Root Module Outputs
    Given the configuration in "testdata/plan-outputs-changed" which modifies root outputs
    And an initial state with outputs: "changed" (before), "sensitive_before" (sensitive, before), "sensitive_after" (before), "removed" (before), "unchanged" (before)
    And a plan output path is specified
    When a Terraform plan operation is run with refresh enabled
    Then the operation should be successful
    And the plan should NOT be empty
    And the standard output should show changes to outputs:
      | OutputName        | ChangeDescription |
      | added             | + "after"         |
      | changed           | "before" -> "after" |
      | removed           | "before" -> null  |
      | sensitive_after   | (sensitive value) |
      | sensitive_before  | (sensitive value) |
    And the standard output should contain "You can apply this plan to save these new output values"

  Scenario: Plan Ignores Changes to Non-Root Module Outputs for Emptiness
    Given the configuration in "testdata/plan-module-outputs-changed" which modifies only module outputs
    And an initial state with module "mod" output "changed" (before)
    And a plan output path is specified
    When a Terraform plan operation is run with refresh enabled
    Then the operation should be successful
    And the plan should be considered empty
    And the standard output should contain "No changes. Your infrastructure matches the configuration."

  Scenario: Plan with Tainted Resource
    Given the configuration in "testdata/plan"
    And an initial state where "test_instance.foo" is tainted
    And a plan output path is specified
    When a Terraform plan operation is run with refresh enabled
    Then the operation should be successful
    And the provider's ReadResource method should have been called for the tainted resource
    And the plan should NOT be empty
    And the standard output should indicate "test_instance.foo" is tainted and must be replaced (destroy and then create)

  Scenario: Plan with Only a Deposed Resource in State
    Given the configuration in "testdata/plan" defines "test_instance.foo"
    And an initial state where "test_instance.foo" only exists as a deposed object (key "00000000")
    And a plan output path is specified
    When a Terraform plan operation is run with refresh enabled
    Then the operation should be successful
    And the provider's ReadResource method should have been called for the deposed object
    And the plan should NOT be empty
    And the standard output should show creation of "test_instance.foo"
    And the standard output should show destruction of "test_instance.foo (deposed object 00000000)"

  Scenario: Plan with Tainted Resource and Create-Before-Destroy Lifecycle
    Given the configuration in "testdata/plan-cbd" for "test_instance.foo" with create_before_destroy
    And an initial state where "test_instance.foo" is tainted
    And a plan output path is specified
    When a Terraform plan operation is run with refresh enabled
    Then the operation should be successful
    And the provider's ReadResource method should have been called
    And the plan should NOT be empty
    And the standard output should indicate "test_instance.foo" is tainted and will be replaced (create replacement and then destroy)

  Scenario: Plan Operation with Refresh Disabled
    Given the configuration in "testdata/plan"
    And an initial state exists for "testdata/plan"
    When a Terraform plan operation is run with refresh disabled
    Then the operation should be successful
    And the provider's ReadResource method should NOT have been called
    And the plan should be empty (assuming no configuration changes against the state)
    And there should be no error output

  Scenario: Destroy Plan Operation
    Given the configuration in "testdata/plan"
    And an initial state exists for "testdata/plan"
    And a plan output path is specified
    When a Terraform destroy plan operation is run with refresh enabled
    Then the operation should be successful
    And the plan should NOT be empty
    And the generated plan file should indicate all resources are marked for deletion
    And there should be no error output

  Scenario: Destroy Plan Operation with Data Sources
    Given the configuration in "testdata/destroy-with-ds" (includes a data source and a managed resource)
    And an initial state exists for "testdata/destroy-with-ds"
    And a plan output path is specified
    When a Terraform destroy plan operation is run with refresh enabled
    Then the operation should be successful
    And the plan should NOT be empty
    And the generated plan file should include the data source but mark only managed resources for deletion
    And the standard output for the destroy plan should only show the managed resource being destroyed

  Scenario: Plan to Output Path with No Changes
    Given the configuration in "testdata/plan"
    And an initial state that matches the configuration
    And a plan output path is specified
    When a Terraform plan operation is run with refresh enabled
    Then the operation should be successful
    And the generated plan file should represent an empty plan (no changes)
    And there should be no error output

  Scenario: Plan Operation with Invalid Options
    Given the configuration in "testdata/plan"
    When a Terraform plan operation is run with refresh enabled, refresh-only mode, and a force-replace target
    Then the operation should fail
    And the error output should indicate an issue with conflicting options

```

Notes:
*   Many scenarios involve setting up initial state (`testStateFile`) or specific provider responses; these are described in the `Given` steps.
*   Plan output checks (`done(t).Stdout()`) are translated to `And the standard output should contain...` or `And the standard output should show...`.
*   Checking `run.PlanEmpty` becomes `And the plan should/should NOT be empty`.
*   "plan output path is specified" implies `op.PlanOutPath` and `op.PlanOutBackend` are set up as in the tests.

This covers the scenarios from `backend_plan_test.go`.

Next is `internal/backend/local/backend_refresh_test.go`.
