# Metadata:
# Covers: internal/backend/local/backend_apply_test.go
# TestFunctions:
# - TestLocal_applyBasic
# - TestLocal_applyCheck
# - TestLocal_applyEmptyDir
# - TestLocal_applyEmptyDirDestroy
# - TestLocal_applyError
# - TestLocal_applyBackendFail
# - TestLocal_applyRefreshFalse
# - TestApply_applyCanceledAutoApprove

Feature: Local Backend Apply Operation
  This feature describes the behavior of the 'apply' operation when using the local backend,
  covering various scenarios including basic applies, error handling, empty configurations,
  and interactions with state and providers.

  Background:
    Given a local backend is initialized for testing
    And a mock "test" provider is configured

  Scenario: Basic Apply Operation
    Given the configuration in "testdata/apply" which defines "test_instance.foo"
    And the mock "test" provider will successfully plan and apply "test_instance.foo" yielding new state with ami "bar" and id "yes"
    When a Terraform apply operation is run
    Then the operation should be successful
    And the provider's PlanResourceChange method should have been called for "test_instance.foo"
    And the provider's ApplyResourceChange method should have been called for "test_instance.foo"
    And the provider's ReadResource method should NOT have been called
    And the final state should contain "test_instance.foo" with ami "bar" and id "yes"
    And there should be no error output

  Scenario: Apply Operation with Check Blocks (Auto-Approved)
    Given the configuration in "testdata/apply-check" which defines "test_instance.foo" and a check block
    And the mock "test" provider will successfully plan and apply "test_instance.foo"
    When a Terraform apply operation is run (auto-approved)
    Then the operation should be successful
    And the provider's ApplyResourceChange method should have been called
    And the standard output should NOT contain "Check block assertion known after apply"

  Scenario: Apply Operation on an Empty Configuration Directory
    Given the configuration in "testdata/empty" (which is an empty directory)
    When a Terraform apply operation is run
    Then the operation should fail
    And the provider's ApplyResourceChange method should NOT have been called
    And no state file should be written at the primary path
    And the backend state lock should be released
    And the error output should contain "No configuration files"

  Scenario: Destroy Operation on an Empty Configuration Directory
    Given the configuration in "testdata/empty" (which is an empty directory)
    When a Terraform destroy operation is run
    Then the operation should be successful
    And the provider's ApplyResourceChange method should NOT have been called
    And the final state should be empty
    And there should be no error output

  Scenario: Apply Operation with Provider Error
    Given the configuration in "testdata/apply-error" which defines "test_instance.foo" and "test_instance.bar"
    And the mock "test" provider will apply "test_instance.foo" successfully (ami "bar", id "foo")
    And the mock "test" provider will return an error "ami error" when applying "test_instance.bar" (with ami "error")
    When a Terraform apply operation is run
    Then the operation should fail
    And the final state should contain "test_instance.foo" with ami "bar" and id "foo"
    And the backend state lock should be released
    And the error output should contain "Error: ami error"

  Scenario: Apply Operation with State Writing Failure
    Given the configuration in "testdata/apply"
    And the mock "test" provider will successfully plan and apply "test_instance.foo"
    And the backend is configured to fail when writing state with message "fake failure"
    When a Terraform apply operation is run
    Then the operation should fail
    And the error output should contain "Error saving state: fake failure"
    And the error output should contain any provider diagnostics (e.g., "error before backend failure" if provider also emitted one)
    And a fallback state file "errored.tfstate" should be created containing the (tainted) state of "test_instance.foo"
    And the backend state lock should be released

  Scenario: Apply Operation (from plan) Does Not Refresh by Default
    Given the configuration in "testdata/plan"
    And an existing state file for "testdata/plan" is present
    And the mock "test" provider is configured
    When a Terraform apply operation is run (implying from a plan, no explicit refresh)
    Then the operation should be successful
    And the provider's ReadResource method should NOT have been called
    And there should be no error output

  Scenario: Canceled Auto-Approved Apply Operation
    Given the configuration in "testdata/apply"
    And the mock "test" provider is configured
    And the apply operation is auto-approved
    When a Terraform apply operation is run
    And the operation is externally canceled during execution
    Then the operation should fail
    And the error output should contain "execution halted"

```

Notes for this Gherkin:
*   The `Background` sets up the local backend and mock provider, common to most tests.
*   Configuration paths are relative to the test execution context.
*   Provider interactions (like `ApplyResourceChangeResponse`) are described in terms of their outcomes.
*   State verification (`checkState` in Go) is translated to `And the final state should contain...` or `And the final state should be empty`.
*   Error output checking (`done(t).Stderr()`) becomes `And the error output should contain...`.
*   The scenario for `TestLocal_applyRefreshFalse` is interpreted as applying a plan where refresh is not part of that specific apply command's direct flags (often meaning a plan file is being applied).
*   The cancellation test uses a more descriptive "externally canceled" phrase.

This covers the core scenarios from `backend_apply_test.go`.

Next, I'll process `internal/backend/local/backend_local_test.go`.
