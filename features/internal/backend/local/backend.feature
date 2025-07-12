# Metadata:
# Covers: internal/backend/local/backend_test.go
# TestFunctions:
# - TestLocal_PrepareConfig
# - TestLocal_useOfPathAttribute
# - TestLocal_pathAttributeWrongExtension
# - TestLocal_useOfWorkspaceDirAttribute
# - TestLocal_cannotDeleteDefaultState
# - TestLocal_addAndRemoveStates
# - TestLocal_StatePaths_defaultWorkspace
# - TestLocal_StatePaths_nonDefaultWorkspace
# - TestLocal_PathsConflictWith
# - TestLocal_callsMethodsOnStateBackend
# Note: TestLocal_impl is a compile-time interface check.
# Note: TestLocal_backend uses generic backend test suites not directly translated here.

Feature: Local Backend Core Functionality
  This feature describes the core behavior of the local backend, including configuration,
  state path management, workspace operations, and delegation for custom state storage.

  Background:
    Given a temporary working directory for local backend tests

  Scenario Outline: Preparing Local Backend Configuration
    Given a local backend instance
    And a backend configuration with path "<Path>" and workspace_dir "<WorkspaceDir>"
    When the backend configuration is prepared
    Then the diagnostic summary should <ContainOrNot> error "<ExpectedError>"

    Examples:
      | Path                          | WorkspaceDir          | ContainOrNot | ExpectedError                                    |
      | ""                            | null                  | contain      | The "path" attribute value must not be empty     |
      | "path/to/state/my-state.docx" | null                  | not contain  |                                                  | # No error for extension
      | null                          | ""                    | contain      | The "workspace_dir" attribute value must not be empty |
      | null                          | "this/does/not/exist" | not contain  |                                                  | # No error for non-existent dir

  Scenario: Effect of 'path' Attribute on State File Location
    Given a local backend instance configured with 'path' attribute as "custom/path/to/foobar.tfstate" and no 'workspace_dir'
    And I write a state to the "default" workspace
    Then a state file should exist at "custom/path/to/foobar.tfstate"
    And when I write a state to the "non_default_ws" workspace
    Then a state file should exist at "terraform.tfstate.d/non_default_ws/terraform.tfstate"

  Scenario: Using Non-Standard Extension in 'path' Attribute
    Given a local backend instance configured with 'path' attribute as "my_state.customext"
    When I write a state to the "default" workspace
    Then a state file should exist at "my_state.customext" containing the written state

  Scenario: Effect of 'workspace_dir' Attribute on State File Location
    Given a local backend instance configured with 'workspace_dir' as "custom/ws_dir" and no 'path'
    And I write a state to the "default" workspace
    Then a state file should exist at "terraform.tfstate"
    And when I write a state to the "prod_ws" workspace
    Then a state file should exist at "custom/ws_dir/prod_ws/terraform.tfstate"

  Scenario: Cannot Delete Default Workspace
    Given a local backend instance
    When I attempt to delete the "default" workspace
    Then the operation should fail with error "cannot delete default state"
    When I attempt to delete the "default" workspace with force
    Then the operation should fail with error "cannot delete default state"

  Scenario: Managing Workspaces
    Given a local backend instance
    Then the list of workspaces should initially be ["default"]
    When I request the state manager for workspace "new_ws_A" (implicitly creating it)
    Then the list of workspaces should contain "default" and "new_ws_A"
    When I request the state manager for workspace "new_ws_B" (implicitly creating it)
    Then the list of workspaces should contain "default", "new_ws_A", and "new_ws_B"
    When I delete workspace "new_ws_A" with force
    Then the list of workspaces should contain "default" and "new_ws_B"
    When I delete workspace "new_ws_B" with force
    Then the list of workspaces should be ["default"]

  Scenario Outline: State Path Determination for Default Workspace
    Given a local backend instance
    And its 'path' configuration is <ConfigPath>
    And its 'OverrideStatePath' is <OverridePath>
    And its 'OverrideStateOutPath' is <OverrideOutPath>
    And its 'OverrideStateBackupPath' is <OverrideBackupPath>
    When state paths are determined for the "default" workspace
    Then the input path should be "<ExpectedInputPath>"
    And the output path should be "<ExpectedOutputPath>"
    And the backup path should be "<ExpectedBackupPath>"

    Examples:
      | ConfigPath          | OverridePath        | OverrideOutPath     | OverrideBackupPath  | ExpectedInputPath   | ExpectedOutputPath  | ExpectedBackupPath          |
      | (not set)           | (not set)           | (not set)           | (not set)           | terraform.tfstate   | terraform.tfstate   | terraform.tfstate.backup    |
      | "custom.tfstate"    | (not set)           | (not set)           | (not set)           | custom.tfstate      | custom.tfstate      | custom.tfstate.backup       |
      | "custom.tfstate"    | "override.tfstate"  | "override.tfstate"  | "override.tfstate"  | override.tfstate    | override.tfstate    | override.tfstate            |

  Scenario Outline: State Path Determination for Non-Default Workspace
    Given a local backend instance for workspace "my_env"
    And its 'path' configuration is <ConfigPath>
    And its 'workspace_dir' configuration is <ConfigWorkspaceDir>
    And its 'OverrideStatePath' is <OverridePath>
    And its 'OverrideStateOutPath' is <OverrideOutPath>
    And its 'OverrideStateBackupPath' is <OverrideBackupPath>
    When state paths are determined for the "my_env" workspace
    Then the input path should be "<ExpectedInputPath>"
    And the output path should be "<ExpectedOutputPath>"
    And the backup path should be "<ExpectedBackupPath>"

    Examples:
      | ConfigPath          | ConfigWorkspaceDir | OverridePath        | OverrideOutPath     | OverrideBackupPath  | ExpectedInputPath                             | ExpectedOutputPath                            | ExpectedBackupPath                                  |
      | (not set)           | (not set)          | (not set)           | (not set)           | (not set)           | terraform.tfstate.d/my_env/terraform.tfstate  | terraform.tfstate.d/my_env/terraform.tfstate  | terraform.tfstate.d/my_env/terraform.tfstate.backup |
      | "custom.tfstate"    | (not set)          | (not set)           | (not set)           | (not set)           | terraform.tfstate.d/my_env/terraform.tfstate  | terraform.tfstate.d/my_env/terraform.tfstate  | terraform.tfstate.d/my_env/terraform.tfstate.backup | # 'path' ignored
      | (not set)           | "custom_ws_dir"    | (not set)           | (not set)           | (not set)           | custom_ws_dir/my_env/terraform.tfstate        | custom_ws_dir/my_env/terraform.tfstate        | custom_ws_dir/my_env/terraform.tfstate.backup       |
      | "custom.tfstate"    | "custom_ws_dir"    | "override.tfstate"  | "override.tfstate"  | "override.tfstate"  | override.tfstate                              | override.tfstate                              | override.tfstate                                    |

  Scenario: Path Conflict Detection
    Given an original local backend "B1" with default state at "foo/terraform.tfstate" and "ws1" workspace state at "terraform.tfstate.d/ws1/terraform.tfstate"
    And a new local backend "B2" configured with 'path' as "terraform.tfstate.d/ws1/terraform.tfstate" # Conflicts with B1's ws1
    Then backend "B1" PathsConflictWith backend "B2" should be true

    Given an original local backend "B1" with default state at "foo/terraform.tfstate"
    And a new local backend "B2" configured with 'workspace_dir' as "." and intending to use workspace "foo" # Results in "foo/terraform.tfstate", conflicts with B1's default
    Then backend "B1" PathsConflictWith backend "B2" should be true

  Scenario: Delegation to Custom State Backend
    Given a local backend instance initialized with a custom delegate backend
    When the local backend's PrepareConfig method is called
    Then the custom delegate backend's PrepareConfig method should be invoked
    When the local backend's Configure method is called
    Then the custom delegate backend's Configure method should be invoked
    When the local backend's StateMgr method is called for workspace "test"
    Then the custom delegate backend's StateMgr method should be invoked for "test"
    When the local backend's Workspaces method is called
    Then the custom delegate backend's Workspaces method should be invoked
    When the local backend's DeleteWorkspace method is called for "test"
    Then the custom delegate backend's DeleteWorkspace method should be invoked for "test"

  Scenario: Service Discovery Aliases for Local Backend
    Given a local backend instance
    When ServiceDiscoveryAliases is called
    Then the result should be an empty list of host aliases

```

Notes:
*   `(not set)` for path/dir config means the corresponding field on `Local` struct is not set or is its zero value (e.g., null for cty.String in config, or empty string for override paths).
*   The state path examples use forward slashes for readability; `filepath.Join` behavior is abstracted.
*   "Delegation" scenario assumes the custom delegate backend returns specific errors/markers that can be checked to confirm delegation, as done in the Go test.

This covers `backend_test.go`. Next is `hook_state_test.go`.
