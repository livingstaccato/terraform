# Source Go File: internal/backend/remote/backend_apply.go
# Source Go Test: internal/backend/remote/backend_apply_test.go

Feature: Remote Backend Apply Operation
  This feature describes the apply operation for the remote backend. It covers
  how the backend interacts with a remote service (like Terraform Cloud/Enterprise)
  to perform an apply, including handling plans, approvals, state, and various
  operational flags. Cty.Value is used for variables and within the state.

  Background:
    Given a remote backend initialized for testing, connected to a mock remote service
    And a Terraform configuration directory (e.g., "./testdata/apply")

  Scenario: Basic remote apply operation
    Given an apply operation is prepared for the default workspace
    And the user will approve the apply when prompted ("yes")
    When the backend performs the apply operation
    Then the operation result should be OperationSuccess
    And the plan should not be empty
    And the UI output should indicate "Running apply in the remote backend"
    And the UI output should show a plan summary (e.g., "1 to add, 0 to change, 0 to destroy")
    And the UI output should show an apply summary (e.g., "1 added, 0 changed, 0 destroyed")
    And the remote state should be updated and lockable afterwards

  Scenario: Remote apply operation is canceled by the user
    Given an apply operation is prepared for the default workspace
    When the backend performs the apply operation
    And the run is stopped (simulating Ctrl-C)
    Then the operation result should not be OperationSuccess
    And the remote state should be lockable afterwards

  Scenario: Remote apply attempted without sufficient permissions
    Given a workspace "prod" exists but the current user lacks apply permissions
    And an apply operation is prepared for workspace "prod"
    When the backend performs the apply operation
    Then the operation result should not be OperationSuccess
    And the error output should contain "Insufficient rights to apply changes"

  Scenario: Remote apply attempted for a VCS-driven workspace
    Given a workspace "prod" exists and is configured for VCS-driven runs
    And an apply operation is prepared for workspace "prod"
    When the backend performs the apply operation
    Then the operation result should not be OperationSuccess
    And the error output should contain "not allowed for workspaces with a VCS"

  Scenario: Remote apply with -auto-approve
    Given an apply operation is prepared for the default workspace with AutoApprove true
    When the backend performs the apply operation
    Then the operation result should be OperationSuccess
    And the UI output should indicate a successful remote apply without prompting for approval

  Scenario: Remote apply that is approved externally (via UI/API)
    Given an apply operation is prepared for the default workspace
    And the user input is mocked to "wait-for-external-update"
    When the backend performs the apply operation
    And the corresponding remote run is approved externally via the mock TFE client
    Then the operation result should be OperationSuccess
    And the UI output should indicate "approved using the UI or API"

  Scenario: Remote apply that is discarded externally
    Given an apply operation is prepared for the default workspace
    And the user input is mocked to "wait-for-external-update"
    When the backend performs the apply operation
    And the corresponding remote run is discarded externally via the mock TFE client
    Then the operation result should not be OperationSuccess
    And the UI output should indicate "discarded using the UI or API"

  Scenario: Remote apply with TF_FORCE_LOCAL_BACKEND set (should run locally)
    Given the environment variable "TF_FORCE_LOCAL_BACKEND" is set to "1"
    And an apply operation is prepared for the default workspace
    And the user will approve the apply when prompted ("yes")
    When the backend performs the apply operation
    Then the operation result should be OperationSuccess
    And the UI output should NOT indicate "Running apply in the remote backend"
    And the UI output should show a plan summary (local execution)
    And the resulting state should have managed resource instance objects

  Scenario: Remote apply for a workspace with remote operations disabled (should run locally)
    Given a workspace "no-operations" exists with remote operations disabled
    And an apply operation is prepared for workspace "no-operations"
    And the user will approve the apply when prompted ("yes")
    When the backend performs the apply operation
    Then the operation result should be OperationSuccess
    And the UI output should NOT indicate "Running apply in the remote backend"
    And the resulting state should have managed resource instance objects

  Scenario: Remote apply encountering a lock timeout
    Given a pending run exists on the remote workspace, blocking new runs
    And an apply operation is prepared with a short lock timeout (e.g., 50ms)
    When the backend performs the apply operation
    Then a SIGINT signal should be received (simulating user interrupt after timeout)
    And the UI output should indicate "Lock timeout exceeded"

  Scenario: Remote destroy operation
    Given an apply operation is prepared for the default workspace with DestroyMode true
    And the user will approve the destroy when prompted ("yes")
    When the backend performs the apply operation (destroy)
    Then the operation result should be OperationSuccess
    And the UI output should show a destroy plan summary (e.g., "0 to add, 0 to change, 1 to destroy")
    And the UI output should show a destroy apply summary (e.g., "0 added, 0 changed, 1 destroyed")

  Scenario: Remote apply with policy checks (Hard Fail)
    Given an apply operation is prepared for configuration "./testdata/apply-policy-hard-failed"
    When the backend performs the apply operation
    Then the operation result should not be OperationSuccess
    And the error output should contain "hard failed" (from Sentinel policy)
    And the UI output should show "Sentinel Result: false"

  Scenario: Remote apply with policy checks (Soft Fail, overridden by user)
    Given an apply operation is prepared for configuration "./testdata/apply-policy-soft-failed"
    And the user input is mocked to override the soft fail ("override") and then approve ("yes")
    When the backend performs the apply operation
    Then the operation result should be OperationSuccess
    And the UI output should show "Sentinel Result: false" but still complete the apply

  Scenario: Remote apply with an error from the remote execution
    Given an apply operation is prepared for configuration "./testdata/apply-with-error"
      # This configuration is set up in the mock client to produce an error during apply
    When the backend performs the apply operation
    Then the operation result should not be OperationSuccess
    And the operation result exit status should be 1
    And the UI output should contain an error message (e.g., "null_resource.foo: 1 error")

  # Note:
  # - cty.Value is used for `op.Variables` and is involved in state representation.
  # - `testOperationApply` sets up a backendrun.Operation.
  # - Mock TFE client (`b.client`) is used to simulate remote interactions (runs, workspaces, policy checks).
  # - UI interactions (prompts for approval, output messages) are handled via `op.UIIn` and `b.CLI` (MockUi).
  # - Plan and state objects are handled, and their cty.Value contents are implicitly part of the flow.
  # - This BDD focuses on the remote backend's orchestration of apply via the TFE API.
  # - Version checks (local vs. remote Terraform version) are also part of the logic but not detailed here for brevity unless they block apply.
  # - Flags like PlanRefresh, PlanMode, AutoApprove, Targets, ForceReplace are passed to the remote run.
  # - The `testdata/` directories contain minimal Terraform configurations.
