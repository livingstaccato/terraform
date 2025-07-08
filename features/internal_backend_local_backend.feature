# Source Go File: internal/backend/local/backend.go
# Source Go Test: internal/backend/local/backend_test.go

Feature: Local Backend Core Functionality
  This feature describes the core functionalities of the local backend,
  including configuration preparation, state path management, and workspace operations.
  It also covers how the local backend delegates to a separate state storage backend if one is provided.

  Background:
    Given a local backend instance

  Scenario Outline: Preparing backend configuration with validation
    Given the local backend is initialized
    And a configuration cty.ObjectVal: <ConfigJSON>
    When PrepareConfig is called with this configuration
    Then diagnostics should <ContainOrNot> errors
    And if errors are expected, the error message should contain "<ExpectedErrorHint>"

    Examples:
      | ConfigJSON                                              | ContainOrNot | ExpectedErrorHint                               |
      | "{\"path\":\"\",\"workspace_dir\":null}"                 | contain      | "path\" attribute value must not be empty"      |
      | "{\"path\":\"path/to/state/my-state.docx\",\"workspace_dir\":null}" | not contain  | ""                                              | # Non .tfstate extension is allowed by PrepareConfig
      | "{\"path\":null,\"workspace_dir\":\"\"}"                 | contain      | "workspace_dir\" attribute value must not be empty" |
      | "{\"path\":null,\"workspace_dir\":\"this/does/not/exist\"}" | not contain  | ""                                              | # Existence not checked by PrepareConfig

  Scenario: Configuring the local backend and its effect on state paths (Default Workspace)
    Given the local backend is initialized in a temporary directory
    And it is configured with cty.ObjectVal: {"path": "custom/path/default.tfstate", "workspace_dir": null}
    When StateMgr is called for the default workspace ""
    And a new state with output "foo"="bar" is written using the StateMgr
    Then the state file should exist at "custom/path/default.tfstate" relative to the temp directory
    And contain the output "foo"="bar"

  Scenario: Configuring the local backend and its effect on state paths (Non-Default Workspace)
    Given the local backend is initialized in a temporary directory
    And it is configured with cty.ObjectVal: {"path": null, "workspace_dir": "custom_workspaces"}
    When StateMgr is called for workspace "my_env"
    And a new state with output "env_out"="test" is written using the StateMgr
    Then the state file should exist at "custom_workspaces/my_env/terraform.tfstate" relative to the temp directory
    And contain the output "env_out"="test"

  Scenario: Deleting workspaces
    Given the local backend is initialized
    When Workspaces is called, it should return ["default"]
    When StateMgr is called for workspace "test_A" (implicitly creating it)
    And StateMgr is called for workspace "test_B" (implicitly creating it)
    Then Workspaces should return ["default", "test_A", "test_B"] (order may vary)
    When DeleteWorkspace "test_A" (force=true) is called
    Then Workspaces should return ["default", "test_B"] (order may vary)
    When DeleteWorkspace "default" (force=true) is called
    Then an error "cannot delete default state" should occur
    And Workspaces should still return ["default", "test_B"] (order may vary)

  Scenario Outline: State path determination for default workspace
    Given a local backend initialized
    And its StatePath is initially <InitialStatePath>
    And its OverrideStatePath is <OverrideStatePath> (or "not set")
    When StatePaths is called for the default workspace ""
    Then the returned path should be "<ExpectedPath>"
    And the returned outPath should be "<ExpectedOutPath>"
    And the returned backupPath should be "<ExpectedBackupPath>"

    Examples:
      | InitialStatePath         | OverrideStatePath    | ExpectedPath             | ExpectedOutPath          | ExpectedBackupPath                 |
      | ""                       | "not set"            | "terraform.tfstate"      | "terraform.tfstate"      | "terraform.tfstate.backup"         |
      | "custom/my.tfstate"      | "not set"            | "custom/my.tfstate"      | "custom/my.tfstate"      | "custom/my.tfstate.backup"         |
      | "custom/my.tfstate"      | "override.tfstate"   | "override.tfstate"       | "override.tfstate"       | "override.tfstate.backup"          | # OverrideStateBackupPath is also override.tfstate in test
      | ""                       | "override.tfstate"   | "override.tfstate"       | "override.tfstate"       | "override.tfstate.backup"          |

  Scenario Outline: State path determination for non-default workspace
    Given a local backend initialized
    And its StateWorkspaceDir is initially <InitialWorkspaceDir>
    And its OverrideStatePath is <OverrideStatePath> (or "not set")
    And the workspace name is "<WorkspaceName>"
    When StatePaths is called for this workspace
    Then the returned path should be "<ExpectedPath>" (paths are relative to temp dir)

    Examples:
      | InitialWorkspaceDir | OverrideStatePath  | WorkspaceName | ExpectedPath                                           |
      | ""                  | "not set"          | "test_env"    | "terraform.tfstate.d/test_env/terraform.tfstate"       |
      | "custom_ws_dir"     | "not set"          | "test_env"    | "custom_ws_dir/test_env/terraform.tfstate"             |
      | "custom_ws_dir"     | "override.tfstate" | "test_env"    | "override.tfstate"                                     | # Override takes precedence

  Scenario: Path conflict detection between backend configurations
    Given an "original" local backend initialized in a temporary directory
    And the original backend (default workspace) state is written to "foobar/terraform.tfstate"
    And the original backend ("foobar" workspace) state is written to "terraform.tfstate.d/foobar/terraform.tfstate"
    And a "new" local backend is initialized
    And the new backend is configured with `path` = "terraform.tfstate.d/foobar/terraform.tfstate" (conflicts with original foobar workspace)
    When PathsConflictWith is called on the original backend with the new backend
    Then the result should be true (conflict detected)

  Scenario: Delegating backend operations when a separate state storage backend is used
    Given a local backend initialized with a separate "delegate" backend that returns specific errors for each method
    When ConfigSchema is called on the local backend, it should return nil (as per test delegate)
    When PrepareConfig is called, a diagnostic containing "prepare config called" should occur
    When Configure is called, a diagnostic containing "configure called" should occur
    When StateMgr is called, an error "state called" should occur
    When Workspaces is called, an error "states called" should occur
    When DeleteWorkspace is called, an error "delete called" should occur

  # Note:
  # - cty.Value is used for backend configurations. State itself (states.State) contains cty.Value for outputs and resources.
  # - TestLocal(t) sets up a temporary directory and a Local backend instance.
  # - DefaultStateFilename is "terraform.tfstate". DefaultWorkspaceDir is "terraform.tfstate.d".
  # - StateMgr interactions (WriteState, ReadState) are implicitly tested by checking file content/existence.
  # - The `PathsConflictWith` scenario implies that if the new backend's default path would collide with an existing workspace path
  #   of the original backend, or vice-versa, a conflict is reported.
  # - The "delegate" backend scenario tests that method calls are passed through, not the cty content itself.
