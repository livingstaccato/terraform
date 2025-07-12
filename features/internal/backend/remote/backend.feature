# Metadata:
# Covers: internal/backend/remote/backend_test.go
# TestFunctions:
# - TestRemote_config
# - TestRemote_versionConstraints (covered by VerifyWorkspaceTerraformVersion scenarios)
# - TestRemote_localBackend
# - TestRemote_addAndRemoveWorkspacesDefault
# - TestRemote_addAndRemoveWorkspacesNoDefault
# - TestRemote_checkConstraints (internal helper, covered by version check scenarios)
# - TestRemote_StateMgr_versionCheck
# - TestRemote_StateMgr_versionCheckLatest
# - TestRemote_VerifyWorkspaceTerraformVersion (and its variants)
# - TestRemote_ServiceDiscoveryAliases
# Note: TestRemote_impl is a compile-time check.
# Note: TestRemote_backendDefault/NoDefault use generic backend test suites.

Feature: Remote Backend Core Functionality and Configuration
  This feature describes the core behavior of the remote backend, including its
  configuration, version compatibility checks with Terraform Cloud/Enterprise (TFE),
  workspace management, and interaction with local execution modes.

  Background:
    Given a remote backend initialized with a mock TFE client and a mock discovery service

  Scenario Outline: Configuring the Remote Backend
    Given a remote backend configuration with:
      | hostname     | organization | token     | workspaces_name | workspaces_prefix |
      | <Hostname>   | <Org>        | <Token>   | <WsName>        | <WsPrefix>        |
    When the backend configuration is prepared and then configured
    Then the prepare diagnostics should <PrepareOutcome> with message part "<PrepareMsgPart>"
    And the configure diagnostics should <ConfigureOutcome> with message part "<ConfigureMsgPart>"

    Examples:
      | Hostname                | Org           | Token     | WsName   | WsPrefix | PrepareOutcome | PrepareMsgPart                                          | ConfigureOutcome | ConfigureMsgPart                                    |
      | app.terraform.io        | nonexisting   | (valid)   | prod     |          | not have errors|                                                         | have errors    | 'organization "nonexisting" at host app.terraform.io not found' |
      | nonexisting.local       | hashicorp     | (valid)   | prod     |          | not have errors|                                                         | have errors    | "Failed to request discovery document"              |
      | localhost               | hashicorp     | (missing) | prod     |          | not have errors|                                                         | have errors    | "terraform login localhost"                         |
      | app.terraform.io        | hashicorp     | (valid)   | prod     |          | not have errors|                                                         | not have errors|                                                     |
      | app.terraform.io        | hashicorp     | (valid)   |          | my-app-  | not have errors|                                                         | not have errors|                                                     |
      | app.terraform.io        | hashicorp     | (valid)   |          |          | have errors    | 'Either workspace "name" or "prefix" is required'       | not have errors|                                                     | # Configure not reached if prepare fails
      | app.terraform.io        | hashicorp     | (valid)   | prod     | my-app-  | have errors    | 'Only one of workspace "name" or "prefix" is allowed' | not have errors|                                                     | # Configure not reached
      | (null_config_value)     |               |           |          |          | not have errors|                                                         | not have errors|                                                     |

  Scenario: Remote Backend's Embedded Local Backend
    Given a remote backend instance
    When it's forced to run locally (e.g. TF_FORCE_LOCAL_BACKEND is set)
    Then its internal local backend component should itself use the remote backend for state storage

  Scenario: Workspace Management with Default Remote Backend Configuration (Single Workspace Mode)
    Given a remote backend configured with a specific workspace (e.g., "default" or named via "workspaces.name")
    When I list available workspaces via the backend
    Then an 'ErrWorkspacesNotSupported' error should occur
    When I try to manage state for the configured workspace (e.g., "default")
    Then the operation should succeed (implicitly, state manager is retrieved)
    When I try to manage state for a different workspace "prod"
    Then an 'ErrWorkspacesNotSupported' error should occur
    When I try to delete the configured workspace "default" (even with force)
    Then the operation should succeed (as it deletes the remote TFE workspace)
    When I try to delete a different workspace "prod" (even with force)
    Then an 'ErrWorkspacesNotSupported' error should occur

  Scenario: Workspace Management with No Default Workspace Configuration (Multiple Workspaces Mode in TFE)
    Given a remote backend configured without a specific default workspace (e.g., using "workspaces.prefix")
    Then the list of workspaces from the backend should initially be empty (from mock TFE)
    When I request the state manager for TFE workspace "test_A" (implicitly creating it on TFE)
    Then the list of workspaces should now include "test_A"
    When I request the state manager for TFE workspace "test_B"
    Then the list of workspaces should now include "test_A" and "test_B"
    When I delete TFE workspace "test_A" via the backend
    Then the list of workspaces should only include "test_B"
    When I attempt to manage state for the "default" workspace locally
    Then an 'ErrDefaultWorkspaceNotSupported' error should occur

  Scenario Outline: Terraform Version Compatibility Check during State Manager Retrieval
    Given the local Terraform version is "<LocalVersion>"
    And the remote TFE workspace is configured for Terraform version "<RemoteVersion>"
    When the state manager for the remote workspace is requested
    Then the operation should <Outcome>
    And if it fails, the error message should contain "<ErrorMessagePart>"

    Examples:
      | LocalVersion | RemoteVersion | Outcome | ErrorMessagePart                                            |
      | "0.14.0"     | "0.14.0"      | succeed |                                                             |
      | "0.14.0"     | "latest"      | succeed |                                                             |
      | "0.14.0"     | "0.13.5"      | fail    | 'Remote workspace Terraform version "0.13.5" does not match'|

  Scenario Outline: Explicit Workspace Terraform Version Verification
    Given the local Terraform CLI version is "<LocalVersion>" (prerelease "<LocalPrerelease>")
    And the remote TFE workspace is configured for Terraform version "<RemoteVersionConstraint>"
    And the remote TFE workspace execution mode is "<ExecutionMode>"
    And version conflict ignorance is <IgnoreConflict>
    When the remote backend verifies the workspace Terraform version
    Then <ExpectedDiagnosticCount> diagnostics should be produced
    And if diagnostics are produced, the first diagnostic severity should be "<ExpectedSeverity>" and summary should contain "<ExpectedSummaryPart>" and detail should contain "<ExpectedDetailPart>"

    Examples:
      | LocalVersion | LocalPrerelease | RemoteVersionConstraint | ExecutionMode | IgnoreConflict | ExpectedDiagnosticCount | ExpectedSeverity | ExpectedSummaryPart        | ExpectedDetailPart                                                           |
      | "0.13.5"     | ""              | "0.13.5"                | remote        | false          | 0                       |                  |                            |                                                                              |
      | "0.14.0"     | ""              | "0.13.5"                | remote        | false          | 1                       | Error            | "Terraform version mismatch" | 'local Terraform version (0.14.0) does not match the configured version for remote workspace .* (0.13.5)' |
      | "0.14.0"     | ""              | "0.13.5"                | local         | false          | 0                       |                  |                            | # No check if exec mode is local                                             |
      | "1.8.0"      | ""              | "> 1.9.0"               | remote        | false          | 1                       | Error            | "Terraform version mismatch" | 'does not satisfy the version constraint > 1.9.0'                            |
      | "1.10.0"     | "dev"           | "> v1.9.4"              | remote        | false          | 0                       |                  |                            | # Prerelease satisfies if base matches constraint for non-prerelease remote  |
      | "0.14.0"     | ""              | "0.13.5"                | remote        | true           | 1                       | Warning          | "Terraform version mismatch" | 'local Terraform version (0.14.0) does not match the configured version for remote workspace .* (0.13.5)' |
      | "1.0.0"      | ""              | "invalid-version"       | remote        | false          | 1                       | Error            | "The remote workspace specified an invalid Terraform version" |                                                                              |

  Scenario: Service Discovery Aliases for Remote Backend
    Given a remote backend configured with hostname "app.terraform.io" and organization "hashicorp" and workspace "prod"
    When ServiceDiscoveryAliases is called
    Then the result should include an alias from "app.terraform.io" to the mock TFE server's hostname

  Scenario: Attempting Refresh Operation with Remote Backend
    Given a remote backend instance
    When a Terraform refresh operation is initiated
    Then the operation should fail
    And the error message should contain "The \"refresh\" operation is not supported when using the \"remote\" backend"
    And the error message should suggest using "terraform apply -refresh-only"

  Scenario Outline: Remote Operation Retry Logging
    Given a remote backend with CLI UI configured
    And a remote operation is initiated that will trigger TFE client retries
    When the TFE client retries the request <RetryCount> times due to server errors
    Then the CLI output should include the initial retry warning "There was an error connecting to the remote backend. Please do not exit Terraform to prevent data loss! Trying to restore the connection..."
    And if <RetryCount> is greater than 1, the CLI output should include subsequent retry warnings like "Still trying to restore the connection... (%s elapsed)"

    Examples:
      | RetryCount |
      | 1          |
      | 3          |

  Scenario Outline: User Prompting for Remote Operation Cancellation
    Given a remote backend with CLI UI configured for input
    And a remote operation (e.g., plan or apply) is running
    And the operation was <AutoApprovedState>
    When the operation receives an external stop signal (Ctrl-C)
    Then the user should <BeOrNot> prompted "Do you want to cancel the remote operation?"
    And if prompted and the user responds "<UserResponse>", the output should contain "<ResponseMessage>"

    Examples:
      | AutoApprovedState | BeOrNot    | UserResponse | ResponseMessage                                |
      | not auto-approved | be         | yes          | The remote operation was successfully cancelled. |
      | not auto-approved | be         | no           | The remote operation was not cancelled.        |
      | auto-approved     | not be     | (n/a)        | The remote operation was successfully cancelled. | # Assumes auto-cancel if auto-approved

  Scenario Outline: Error Message Formatting for TFE Client Errors
    Given a remote backend operation encounters a TFE client error of type "<ErrorType>" with original message "<OriginalMessage>"
    When the backend processes this error
    Then the final user-facing error diagnostic should contain the prefix "<PrefixMessage>"
    And the final user-facing error diagnostic should contain the original message "<OriginalMessage>"
    And the final user-facing error diagnostic should contain the help text "<HelpText>"

    Examples:
      | ErrorType             | OriginalMessage          | PrefixMessage                                                              | HelpText                                                                                                                                                             |
      | ResourceNotFound      | "workspace my-ws missing"| "Failed to retrieve run: workspace my-ws missing" (or similar context)       | "The configured \"remote\" backend returns '404 Not Found' errors for resources that do not exist, as well as for resources that a user doesn't have access to." |
      | GenericNetworkError   | "connection timed out"   | "Failed to retrieve run: connection timed out" (or similar context)          | "The configured \"remote\" backend encountered an unexpected error. Sometimes this is caused by network connection problems"                                      |
      # ContextCanceled is handled by returning err directly, so no extra formatting from generalError

  Scenario: Fetching Non-Existent or Inaccessible Workspace
    Given a remote backend instance
    When an attempt is made to fetch TFE workspace "non_existent_ws"
    Then the operation should fail
    And the error message should contain 'workspace non_existent_ws not found'
    And the error message should include advice to check rights and token


```

Notes:
*   This is a complex one. The BDD tries to capture the main configuration validation points, workspace behaviors (which are different from local backend), and version checking logic.
*   `(valid)` and `(missing)` for token are conceptual; the actual test might use a real or no token with a mock server. `(null_config_value)` means `cty.NullVal(cty.EmptyObject)`.
*   The "Workspace Management" scenarios distinguish between "default remote" (single workspace mode via `workspaces.name`) and "no default remote" (multi-workspace mode via `workspaces.prefix`).
*   Version check scenarios are detailed, covering exact matches, "latest", mismatches, constraint satisfaction, and the effect of `IgnoreVersionConflict`.

This is a large feature file due to the many conditions tested in `backend_test.go`.

Next is `internal/backend/remote/remote_test.go`.
