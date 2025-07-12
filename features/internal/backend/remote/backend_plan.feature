# Metadata:
# Covers: internal/backend/remote/backend_plan_test.go
# TestFunctions: (List is extensive, covering most from the Go file)
# - TestRemote_planBasic
# - TestRemote_planCanceled
# - TestRemote_planLongLine
# - TestRemote_planWithoutPermissions
# - TestRemote_planWithParallelism
# - TestRemote_planWithPlan
# - TestRemote_planWithPath
# - TestRemote_planWithoutRefresh
# - TestRemote_planWithoutRefreshIncompatibleAPIVersion
# - TestRemote_planWithRefreshOnly
# - TestRemote_planWithRefreshOnlyIncompatibleAPIVersion
# - TestRemote_planWithTarget
# - TestRemote_planWithTargetIncompatibleAPIVersion
# - TestRemote_planWithReplace
# - TestRemote_planWithReplaceIncompatibleAPIVersion
# - TestRemote_planWithVariables
# - TestRemote_planNoConfig
# - TestRemote_planNoChanges
# - TestRemote_planForceLocal
# - TestRemote_planWithoutOperationsEntitlement
# - TestRemote_planWorkspaceWithoutOperations
# - TestRemote_planLockTimeout
# - TestRemote_planDestroy
# - TestRemote_planDestroyNoConfig
# - TestRemote_planWithWorkingDirectory
# - TestRemote_planWithWorkingDirectoryFromCurrentPath
# - TestRemote_planCostEstimation
# - TestRemote_planPolicyPass
# - TestRemote_planPolicyHardFail
# - TestRemote_planPolicySoftFail
# - TestRemote_planWithRemoteError
# - TestRemote_planOtherError
# - TestRemote_planWithGenConfigOut

Feature: Remote Backend Plan Operation
  This feature describes the behavior of the 'plan' operation when using the remote backend,
  simulating interactions with a Terraform Cloud/Enterprise environment, including various
  options, error conditions, and policy checks.

  Background:
    Given a remote backend initialized with a mock TFE client
    And a Terraform configuration in directory "testdata/plan"

  Scenario: Basic Remote Plan Operation
    When a Terraform plan operation is run against the remote backend
    Then the operation should be successful
    And the plan should NOT be empty
    And the output should indicate the plan ran in the remote backend
    And the output should show a plan summary (e.g., "1 to add, 0 to change, 0 to destroy")
    And the remote state should be unlocked

  Scenario: Canceled Remote Plan Operation
    Given a Terraform plan operation is initiated against the remote backend
    When the operation is externally canceled (e.g., Ctrl-C)
    Then the operation should fail
    And the remote state should be unlocked

  Scenario Outline: Remote Plan with Workspace Restrictions or Unsupported Options
    Given the remote plan operation is configured with <ConditionOrOption>
    When a Terraform plan operation is run against the remote backend
    Then the operation should fail
    And the error output should contain "<ExpectedErrorMessage>"

    Examples:
      | ConditionOrOption                        | ExpectedErrorMessage                                     |
      | insufficient plan permissions in workspace | "Insufficient rights to generate a plan"             |
      | parallelism set to 3                     | "parallelism values are currently not supported"         |
      | a local plan file provided as input      | "saved plan is currently not supported"                | # Cannot provide an input plan file to a remote plan op
      | an output path for the plan specified    | "generated plan is currently not supported"            | # Cannot use -out with remote plan
      | variables provided via CLI               | "variables are currently not supported"                |
      | an empty configuration directory         | "configuration files found"                            |
      | generate config out path specified       | "Generating configuration is not currently supported"  |

  Scenario Outline: Remote Plan with Modifiers and API Version Compatibility
    Given the plan operation is configured with modifier "<PlanModifier>"
    And the remote TFE API version is "<APIVersion>"
    When a Terraform plan operation is run against the remote backend
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

  Scenario: Remote Plan with No Changes
    Given the configuration directory is "testdata/plan-no-changes"
    When a Terraform plan operation is run against the remote backend
    Then the operation should be successful
    And the plan should be empty
    And the output should indicate "No changes. Infrastructure is up-to-date."
    And the output should show policy check results (e.g., "Sentinel Result: true")

  Scenario Outline: Remote Plan Execution Mode Based on Overrides and Entitlements
    Given the environment variable "TF_FORCE_LOCAL_BACKEND" is set to "<ForceLocal>"
    And the remote workspace is configured with operations <OperationsEntitlement>
    When a Terraform plan operation is run
    Then the operation should be successful
    And the plan should run <ExpectedExecutionLocation>
    And the output should show a plan summary

    Examples:
      | ForceLocal | OperationsEntitlement      | ExpectedExecutionLocation |
      | true       | enabled (has entitlement)  | locally                   |
      | false      | disabled (no entitlement)| locally                   |
      | false      | disabled (workspace setting)| locally                   |
      | false      | enabled (has entitlement)  | remotely                  |

  Scenario: Remote Plan with Lock Timeout
    Given another run has locked the remote state for the workspace
    And the plan operation is configured with a short lock timeout (e.g., 50ms)
    And the user will choose to cancel when prompted after timeout
    When a Terraform plan operation is run against the remote backend
    Then the operation should eventually be interrupted by SIGINT (simulated after timeout)
    And the output should contain "Lock timeout exceeded"
    And the operation should ultimately fail

  Scenario Outline: Remote Destroy Plan Operation
    Given the configuration directory is "<ConfigDir>"
    When a Terraform destroy plan operation is run against the remote backend
    Then the operation should be successful
    And the plan should NOT be empty (or empty if ConfigDir is "testdata/empty")
    And the output should indicate a destroy plan

    Examples:
      | ConfigDir          |
      | testdata/plan      | # Has resources to destroy
      | testdata/empty     | # Nothing to destroy, but plan runs

  Scenario: Remote Plan with Custom Workspace Working Directory
    Given the remote workspace is configured with working directory "terraform"
    And the configuration is in "testdata/plan-with-working-directory/terraform"
    When a Terraform plan operation is run (from the parent of the config directory)
    Then the operation should be successful
    And the output should contain a warning about the remote working directory being used
    And the output should show a plan summary

  Scenario: Remote Plan with Cost Estimation
    Given the configuration directory is "testdata/plan-cost-estimation"
    When a Terraform plan operation is run against the remote backend
    Then the operation should be successful
    And the output should show cost estimation information (e.g., "Resources: 1 of 1 estimated")

  Scenario Outline: Remote Plan with Policy Checks
    Given the configuration directory is "<ConfigDir>" (which triggers a specific policy outcome)
    When a Terraform plan operation is run against the remote backend
    Then the operation should <Outcome>
    And the output should show "Sentinel Result: <PolicyResult>"
    And if failed, the error output should contain "<FailureReason>"

    Examples:
      | ConfigDir                          | Outcome | PolicyResult | FailureReason |
      | testdata/plan-policy-passed        | succeed | true         |               |
      | testdata/plan-policy-hard-failed   | fail    | false        | "hard failed" |
      | testdata/plan-policy-soft-failed   | fail    | false        | "soft failed" | # Plan fails on soft-fail, apply can override

  Scenario: Remote Plan with Provider Error During Remote Execution
    Given the configuration in "testdata/plan-with-error" (causes provider error on plan)
    When a Terraform plan operation is run against the remote backend
    Then the operation should fail with exit code 1
    And the output should contain "null_resource.foo: 1 error" (or similar provider error)

  Scenario: Remote Plan with Generic TFE Client Error
    Given the remote workspace name is "network-error" (configured to cause a generic client error)
    When a Terraform plan operation is run against the remote backend
    Then the operation should fail
    And the error output should contain "the configured \"remote\" backend encountered an unexpected error"
    And the error output should contain "I'm a little teacup"

```

Notes:
*   This is a large BDD file, abstracting many specific Go test function setups into parameterized scenarios or descriptive `Given` steps.
*   The "Plan Modifiers and API Version Compatibility" scenario is a good example of combining several related tests.
*   "Remote Plan Execution Mode..." covers various ways a plan might end up running locally despite using the remote backend.
*   Policy check scenarios for plan are slightly different from apply (e.g., soft-fail during plan is a plan failure, user can choose to apply anyway).

This is a significant chunk. Next is `internal/backend/remote/backend_state_test.go`.
