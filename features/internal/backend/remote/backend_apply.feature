# Metadata:
# Covers: internal/backend/remote/backend_apply_test.go
# TestFunctions:
# - TestRemote_applyBasic
# - TestRemote_applyCanceled
# - TestRemote_applyWithoutPermissions
# - TestRemote_applyWithVCS
# - TestRemote_applyWithParallelism
# - TestRemote_applyWithPlan
# - TestRemote_applyWithoutRefresh
# - TestRemote_applyWithoutRefreshIncompatibleAPIVersion
# - TestRemote_applyWithRefreshOnly
# - TestRemote_applyWithRefreshOnlyIncompatibleAPIVersion
# - TestRemote_applyWithTarget
# - TestRemote_applyWithTargetIncompatibleAPIVersion
# - TestRemote_applyWithReplace
# - TestRemote_applyWithReplaceIncompatibleAPIVersion
# - TestRemote_applyWithVariables
# - TestRemote_applyNoConfig
# - TestRemote_applyNoChanges
# - TestRemote_applyNoApprove
# - TestRemote_applyAutoApprove
# - TestRemote_applyApprovedExternally
# - TestRemote_applyDiscardedExternally
# - TestRemote_applyWithAutoApply
# - TestRemote_applyForceLocal
# - TestRemote_applyWorkspaceWithoutOperations
# - TestRemote_applyLockTimeout
# - TestRemote_applyDestroy
# - TestRemote_applyDestroyNoConfig
# - TestRemote_applyPolicyPass
# - TestRemote_applyPolicyHardFail
# - TestRemote_applyPolicySoftFail
# - TestRemote_applyPolicySoftFailAutoApproveSuccess
# - TestRemote_applyPolicySoftFailAutoApply
# - TestRemote_applyWithRemoteError
# - TestRemote_applyVersionCheck

Feature: Remote Backend Apply Operation
  This feature describes the behavior of the 'apply' operation when using the remote backend,
  simulating interactions with a Terraform Cloud/Enterprise environment.

  Background:
    Given a remote backend initialized with a mock TFE client
    And a Terraform configuration in directory "testdata/apply"

  Scenario: Basic Remote Apply Operation with User Approval
    Given the user will approve the apply operation when prompted
    When a Terraform apply operation is run against the remote backend
    Then the operation should be successful
    And the output should indicate the apply ran in the remote backend
    And the output should show a plan summary (e.g., "1 to add, 0 to change, 0 to destroy")
    And the output should show an apply summary (e.g., "1 added, 0 changed, 0 destroyed")
    And the remote state should be unlocked

  Scenario: Canceled Remote Apply Operation
    Given a Terraform apply operation is initiated against the remote backend
    When the operation is externally canceled (e.g., Ctrl-C)
    Then the operation should fail
    And the remote state should be unlocked

  Scenario Outline: Remote Apply with Workspace Restrictions
    Given the remote workspace is configured with <WorkspaceRestriction>
    When a Terraform apply operation is run against the remote backend
    Then the operation should fail
    And the error output should contain "<ExpectedErrorMessage>"

    Examples:
      | WorkspaceRestriction                 | ExpectedErrorMessage                             |
      | insufficient apply permissions       | "Insufficient rights to apply changes"           |
      | VCS integration enabled              | "not allowed for workspaces with a VCS"          |
      | remote operations disabled         | (Apply runs locally, covered in another scenario)|

  Scenario Outline: Remote Apply with Unsupported CLI Options
    Given the apply operation is configured with <UnsupportedOption>
    When a Terraform apply operation is run against the remote backend
    Then the operation should fail
    And the error output should contain "<ExpectedErrorMessage>"

    Examples:
      | UnsupportedOption                        | ExpectedErrorMessage                               |
      | parallelism set to 3                   | "parallelism values are currently not supported"   |
      | a local plan file provided             | "saved plan is currently not supported"            |
      | variables provided via CLI             | "variables are currently not supported"            |

  Scenario Outline: Remote Apply with Plan Modifiers and API Version Compatibility
    Given the apply operation is configured with plan modifier "<PlanModifier>"
    And the remote TFE API version is "<APIVersion>"
    When a Terraform apply operation is run against the remote backend
    Then the operation should <Outcome>
    And if successful, the TFE run should reflect "<ExpectedRunProperty>"
    And if failed, the error output should contain "<ExpectedErrorMessage>"

    Examples:
      | PlanModifier        | APIVersion | Outcome   | ExpectedRunProperty | ExpectedErrorMessage                               |
      | refresh disabled    | "2.4"      | succeed   | Refresh:false       |                                                    |
      | refresh disabled    | "2.3"      | fail      |                     | "Planning without refresh is not supported"        |
      | refresh-only mode   | "2.4"      | succeed   | RefreshOnly:true    |                                                    |
      | refresh-only mode   | "2.3"      | fail      |                     | "Refresh-only mode is not supported"               |
      | target "null_resource.foo" | "2.3" | succeed | TargetAddrs: ["null_resource.foo"] |                                  |
      | target "null_resource.foo" | "2.2" | fail    |                     | "Resource targeting is not supported"              |
      | replace "null_resource.foo"| "2.4" | succeed | ReplaceAddrs: ["null_resource.foo"] |                                |
      | replace "null_resource.foo"| "2.3" | fail    |                     | "Planning resource replacements is not supported"  |

  Scenario: Remote Apply on Empty Configuration
    Given the configuration directory is "testdata/empty"
    When a Terraform apply operation is run against the remote backend
    Then the operation should fail
    And the error output should contain "configuration files found" # Or similar
    And the remote state should be unlocked

  Scenario: Remote Apply with No Changes
    Given the configuration directory is "testdata/apply-no-changes"
    And the user will approve the apply operation when prompted
    When a Terraform apply operation is run against the remote backend
    Then the operation should be successful
    And the output should indicate "No changes. Infrastructure is up-to-date."
    And the output should show policy check results (e.g., "Sentinel Result: true")

  Scenario Outline: Remote Apply User Approval Flow
    Given the user will respond with "<UserResponse>" when prompted to approve the apply
    When a Terraform apply operation is run against the remote backend
    Then the operation should <Outcome>
    And if it fails, the error output should contain "<ExpectedMessage>"

    Examples:
      | UserResponse | Outcome | ExpectedMessage   |
      | no           | fail    | "Apply discarded" |
      | yes          | succeed |                   |

  Scenario: Remote Apply with Auto-Approve Flag
    Given the apply operation is configured with auto-approve
    When a Terraform apply operation is run against the remote backend
    Then the operation should be successful
    And the user should NOT be prompted for approval
    And the output should show successful application

  Scenario Outline: Remote Apply with External Run Management
    Given the user will respond with "wait-for-external-update" when prompted to approve the apply
    And a Terraform apply operation is initiated against the remote backend, creating a TFE run
    When the TFE run is externally <ExternalAction> via the API
    Then the CLI operation should <Outcome>
    And the output should indicate the run was <ExternalActionMessagePart> using the UI or API

    Examples:
      | ExternalAction | Outcome | ExternalActionMessagePart |
      | approved       | succeed | approved                  |
      | discarded      | fail    | discarded                 |

  Scenario: Remote Apply with Workspace Auto-Apply Enabled
    Given the remote workspace is configured for auto-apply
    When a Terraform apply operation is run against the remote backend
    Then the operation should be successful
    And the user should NOT be prompted for approval (run applies automatically in TFE)
    And the output should show successful application

  Scenario Outline: Remote Apply Execution Mode Override
    Given the environment variable "TF_FORCE_LOCAL_BACKEND" is set to "<ForceLocal>"
    And the remote workspace execution mode is "<RemoteExecutionMode>"
    And the remote TFE version is "<TFEVersion>" and local Terraform version is "<LocalVersion>"
    And the user will approve the apply operation when prompted
    When a Terraform apply operation is run
    Then the operation should <Outcome>
    And the apply should run <ExpectedExecutionLocation>
    And if an error is expected, the error output should contain "<ExpectedErrorMessage>"

    Examples:
      | ForceLocal | RemoteExecutionMode | TFEVersion | LocalVersion | Outcome | ExpectedExecutionLocation | ExpectedErrorMessage |
      | true       | remote              | "0.13.5"   | "0.14.0"     | succeed | locally                   |                      | # Versions can differ if forced local
      | false      | local               | "0.13.5"   | "0.14.0"     | succeed | locally                   |                      | # Workspace set to local exec
      | false      | remote              | "0.13.5"   | "0.14.0"     | succeed | remotely                  |                      | # Remote exec, versions can differ

  Scenario: Remote Apply with Lock Timeout
    Given another run has locked the remote state for the workspace
    And the apply operation is configured with a short lock timeout (e.g., 50ms)
    And the user will choose to cancel when prompted after timeout
    When a Terraform apply operation is run against the remote backend
    Then the operation should eventually be interrupted by SIGINT (simulated after timeout)
    And the output should contain "Lock timeout exceeded"
    And the operation should ultimately fail

  Scenario Outline: Remote Destroy Operation
    Given the configuration directory is "<ConfigDir>"
    And the user will approve the destroy operation when prompted
    When a Terraform destroy operation is run against the remote backend
    Then the operation should be successful
    And the output should indicate a destroy plan (e.g., "0 to add, 0 to change, 1 to destroy")
    And the output should indicate successful destruction

    Examples:
      | ConfigDir               |
      | testdata/apply-destroy  |
      | testdata/empty          | # Destroying an empty config

  Scenario Outline: Remote Apply with Policy Checks
    Given the configuration directory is "<ConfigDir>" (which triggers a specific policy outcome)
    And the user will respond with "<UserInteraction>" to any prompts
    When a Terraform apply operation is run against the remote backend
    Then the operation should <Outcome>
    And the output should show "Sentinel Result: <PolicyResult>"
    And if successful, the output should show successful application
    And if failed, the error output should contain "<FailureReason>"

    Examples:
      | ConfigDir                          | UserInteraction | Outcome | PolicyResult | FailureReason     |
      | testdata/apply-policy-passed       | "yes"           | succeed | true         |                   |
      | testdata/apply-policy-hard-failed  | "yes"           | fail    | false        | "hard failed"     |
      | testdata/apply-policy-soft-failed  | "override"      | succeed | false        |                   | # User overrides soft-fail
      | testdata/apply-policy-soft-failed  | "yes"           | succeed | false        |                   | # Auto-approve for soft-fail (if -auto-approve)

  Scenario: Remote Apply with Provider Error During Remote Execution
    Given the configuration in "testdata/apply-with-error" (causes provider error on apply)
    And the user will approve the apply operation when prompted
    When a Terraform apply operation is run against the remote backend
    Then the operation should fail with exit code 1
    And the output should contain "null_resource.foo: 1 error" (or similar provider error)

```

Notes:
*   This is a large BDD file due to the many test cases in the Go file. It tries to group related behaviors.
*   "TFE" is used as shorthand for Terraform Cloud/Enterprise service.
*   `<ExpectedRunProperty>` in the "Plan Modifiers" scenario is a way to abstract checking fields on the `tfe.RunCreateOptions` sent to the mock client.
*   The `TF_FORCE_LOCAL_BACKEND` and workspace execution mode tests are combined for brevity.
*   Error messages are quoted from the Go test where specific messages are asserted.
*   Policy check scenarios are simplified; the Go tests have more detailed interactions with auto-approve flags.

This is a substantial piece. Next is `internal/backend/remote/backend_context_test.go`.
