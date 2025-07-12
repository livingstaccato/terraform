# Metadata:
# Covers: internal/backend/remote-state/cos/backend_test.go, internal/backend/remote-state/cos/backend.go
# TestFunctions from backend_test.go:
# - TestStateFile
# - TestRemoteClient (and its variants for prefix, encryption, endpoint)
# - TestRemoteLocks
# - TestBackend (and its variants for prefix, encryption, endpoint)
# Additional behavior for config validation/defaults from backend.go source analysis.

Feature: Tencent Cloud Object Storage (COS) Remote State Backend
  This feature describes the behavior of the Tencent Cloud COS remote state backend,
  including configuration, state object key construction, state operations, and locking.

  Background:
    Given a Tencent Cloud COS environment is available and configured for testing (APPID, region, credentials)
    And a COS bucket named "my-tfstate-bucket" is available

  Scenario Outline: Backend Configuration Validation and Defaults for COS
    Given the COS backend is configured with <ConfigurationDetail>
    When the backend configuration is prepared and then configured by Terraform
    Then the operation should <Outcome>
    And if it fails, the error message should contain "<ExpectedErrorMessagePart>"
    And if successful, the backend instance should reflect <ExpectedSetting>

    Examples:
      | ConfigurationDetail                                     | Outcome | ExpectedErrorMessagePart | ExpectedSetting                               |
      | missing 'region'                                        | fail    | "region" is required     |                                               |
      | missing 'bucket'                                        | fail    | "bucket" is required     |                                               |
      | no 'key' (uses default)                                 | succeed |                          | key is "terraform.tfstate"                    |
      | no 'encrypt' (uses default)                             | succeed |                          | encryption is enabled                         |
      | no 'acl' (uses default)                                 | succeed |                          | ACL is "private"                              |
      | no 'accelerate' (uses default)                          | succeed |                          | acceleration is disabled                      |
      | 'prefix' = "/invalid_prefix"                            | fail    | "prefix must not start with '/'" |                                           |
      | 'key' = "/invalid_key.tfstate"                          | fail    | "key can not start and end with '/'" |                                       |
      | 'key' = "invalid_key.tfstate/"                          | fail    | "key can not start and end with '/'" |                                       |
      | 'acl' = "public_read_write"                             | fail    | "acl value invalid"      |                                               |
      | 'assume_role.session_duration' = -100                   | fail    | "cannot be lower than 0" |                                               |
      | 'assume_role.session_duration' = 50000                  | fail    | "cannot be higher than 43200" |                                           |
      | valid minimal config (region, bucket)                   | succeed |                          | key is "terraform.tfstate", acl "private"     |

  Scenario Outline: State and Lock File Key Construction in COS
    Given the COS backend is configured with bucket "my-tfstate-bucket", prefix "<Prefix>", and key "<Key>"
    When the object key for workspace "<WorkspaceName>" is determined
    Then the state file key should be "<ExpectedStateFileKey>"
    And the lock file key should be "<ExpectedLockFileKey>"

    Examples:
      | Prefix           | Key               | WorkspaceName | ExpectedStateFileKey                            | ExpectedLockFileKey                                 |
      |                  | "default.tfstate" | default       | default.tfstate                                 | default.tfstate.tflock                              |
      |                  | "test.tfstate"    | default       | test.tfstate                                    | test.tfstate.tflock                                 |
      |                  | "test.tfstate"    | dev           | dev/test.tfstate                                | dev/test.tfstate.tflock                             |
      | terraform/test   | "default.tfstate" | default       | terraform/test/default.tfstate                  | terraform/test/default.tfstate.tflock               |
      | terraform/test   | "test.tfstate"    | default       | terraform/test/test.tfstate                     | terraform/test/test.tfstate.tflock                  |
      | terraform/test   | "test.tfstate"    | dev           | terraform/test/dev/test.tfstate                 | terraform/test/dev/test.tfstate.tflock              |

  Scenario Outline: Core State Operations with COS Backend (<CaseDescription>)
    # This scenario implicitly tests successful configuration with various auth methods
    # and settings like encryption or custom endpoints.
    Given the COS backend is configured with bucket "my-tfstate-bucket", prefix "<Prefix>", key "<Key>", encryption <Encryption>, custom endpoint "<Endpoint>", and authentication method "<AuthMethod>"
    When I write a new Terraform state "S1" to the backend for workspace "default"
    Then the operation should succeed
    And if <Encryption> is enabled, the object in COS should be stored with server-side encryption (SSE-C)
    And when I read the state from the backend for workspace "default"
    Then the retrieved state should be equal to "S1"
    And when I list workspaces (states)
    Then the list should include "default" (and others based on prefix structure if applicable)
    When I delete the state for workspace "default"
    Then the operation should succeed
    And reading the state again for "default" should indicate it's not found or is empty

    Examples:
      | CaseDescription        | Prefix   | Key                 | Encryption | Endpoint            | AuthMethod        |
      | Default config         |          | "terraform.tfstate" | disabled   | (COS default)       | StaticKeys        |
      | With prefix            | "teamA/" | "projectX.tfstate"  | disabled   | (COS default)       | StaticKeys        |
      | With encryption        |          | "secure.tfstate"    | enabled    | (COS default)       | StaticKeys        |
      | With custom endpoint   |          | "terraform.tfstate" | disabled   | "http://my.cos.api" | StaticKeys        |
      # Add examples for other AuthMethods: SharedCredentials, CAMRole, AssumeRole if they can be mocked/tested

  Scenario: State Locking and Unlocking with COS Backend
    Given two COS backend instances "B1" and "B2" configured for the same bucket "my-tfstate-bucket", prefix "", and key "locking_test.tfstate"
    When "B1" acquires a lock on the state
    Then "B1" should successfully hold the lock
    And when "B2" attempts to acquire a lock on the same state
    Then "B2" should fail to acquire the lock
    When "B1" releases its lock
    Then the operation should succeed
    And when "B2" attempts to acquire a lock on the state again
    Then "B2" should successfully acquire the lock

  Scenario: Force Unlocking State with COS Backend
    Given a COS backend instance "B1" configured for bucket "my-tfstate-bucket", prefix "", and key "force_lock_test.tfstate"
    And another process "ExternalLockHolder" has locked the state object in COS
    When "B1" attempts to force unlock the state
    Then the force unlock operation should succeed
    And when "B1" attempts to acquire a lock on the state
    Then "B1" should successfully acquire the lock

  Scenario Outline: COS Backend Authentication Configuration Errors
    Given the COS backend is configured with <AuthConfigDetail> that is invalid
    When the backend configuration is prepared and then configured by Terraform
    Then the initialization should fail
    And the error message should contain "<ExpectedErrorMessagePart>"

    Examples:
      | AuthConfigDetail                                     | ExpectedErrorMessagePart           |
      | invalid custom endpoint "bad_scheme://my.cos.api"    | "Invalid URL"                      | # From url.Parse in configure
      | assume_role with invalid session_duration (e.g., text)| "strconv.Atoi"                     | # From handleAssumeRole if env var is bad
      | assume_role fails due to STS client error (mocked)   | (Error from stsClient.AssumeRole)  |
      | getAuthFromCAM fails (mocked metadata service error) | (Error from getAuthFromCAM)        |
      | shared_credentials_dir with non-existent file        | (Error reading credentials file)   |

  Scenario: COS Backend Endpoint Construction
    Given the COS backend is configured with region "ap-singapore", bucket "mybucket", accelerate <Accelerate>, and custom endpoint "<CustomEndpoint>"
    When the COS client endpoint URL is constructed
    Then the URL should be "<ExpectedURL>"

    Examples:
      | Accelerate | CustomEndpoint      | ExpectedURL                                                 |
      | false      |                     | "https://mybucket.cos.ap-singapore.myqcloud.com"            |
      | true       |                     | "https://mybucket.cos.accelerate.myqcloud.com"              |
      | false      | "http://custom.cos" | "http://custom.cos"                                         | # Actual logic is more complex for internal endpoints
      | false      | "https://mybucket.cos-internal.ap-beijing.tencentcos.cn" | "https://mybucket.cos-internal.ap-beijing.tencentcos.cn" |

  Scenario: Automatic State Initialization for New Non-Default Workspace in COS
    Given the COS backend is configured with bucket "my-tfstate-bucket", base key "project.tfstate"
    And the COS object "project.tfstate-env:new_workspace" does not initially exist in the bucket
    When the state manager is requested for the "new_workspace" workspace
    Then the operation should succeed
    And an empty Terraform state should be written to the COS object "project.tfstate-env:new_workspace"
    And this initial empty state should be persisted
    And the state object should have been locked and then unlocked during this initialization

  Scenario: COS API Requests Include Terraform User Agent
    Given the COS backend is configured and will make an API call to write state
    When the backend sends a request to the Tencent Cloud COS API
    Then the HTTP request should include an "X-TC-RequestClient" header with a value like "Terraform-latest"

  Scenario: COS API Requests User Agent Override via Environment Variable
    Given the COS backend is configured
    And the environment variable "TENCENTCLOUD_API_REQUEST_CLIENT" is set to "CustomClient/1.0"
    And the backend will make an API call to write state
    When the backend sends a request to the Tencent Cloud COS API
    Then the HTTP request should include an "X-TC-RequestClient" header with the value "CustomClient/1.0"
