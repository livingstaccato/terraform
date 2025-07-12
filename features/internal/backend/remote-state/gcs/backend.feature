# Metadata:
# Covers: internal/backend/remote-state/gcs/backend_test.go
# TestFunctions:
# - TestAccBackendConfig_credentials
# - TestAccRemoteClient (and variants)
# - TestAccRemoteLocks
# - TestAccBackend (and variants)
# Note: Relies on generic backend.TestBackendStates, TestBackendStateLocks, TestBackendStateForceUnlock suites.

Feature: Google Cloud Storage (GCS) Remote State Backend
  This feature describes the behavior of the Google Cloud Storage (GCS) remote state backend,
  including configuration (credentials, encryption, prefix), state operations, and locking.

  Background:
    Given a Google Cloud Platform environment is available and configured for testing (project, credentials)
    And a GCS bucket named "my-tfstate-gcs-bucket" is available

  Scenario Outline: GCS Backend Credential Resolution
    Given the GCS backend is configured for bucket "my-tfstate-gcs-bucket"
    And the 'credentials' field in backend configuration is <ConfigCredentialsPresence>
    And environment variable "GOOGLE_BACKEND_CREDENTIALS" is <EnvBackendCredentialsPresence>
    And environment variable "GOOGLE_CREDENTIALS" is <EnvCredentialsPresence>
    When the backend initializes its GCS client
    Then the client should be successfully initialized using credentials from <ExpectedCredentialSource>
    And basic state operations (Put, Get) should succeed

    Examples:
      | ConfigCredentialsPresence       | EnvBackendCredentialsPresence | EnvCredentialsPresence      | ExpectedCredentialSource        |
      | set to "valid_config_creds_json"| set to "env_backend_json"   | set to "env_json"           | configuration block             |
      | set to "" (empty string)        | set to "env_backend_json"   | set to "env_json"           | GOOGLE_BACKEND_CREDENTIALS env var|
      | set to "" (empty string)        | unset                       | set to "env_json"           | GOOGLE_CREDENTIALS env var      |
      | unset                           | set to "env_backend_json"   | set to "env_json"           | GOOGLE_BACKEND_CREDENTIALS env var|
      | unset                           | unset                       | set to "env_json"           | GOOGLE_CREDENTIALS env var      |

  Scenario Outline: Core State Operations with GCS Backend (<CaseDescription>)
    Given the GCS backend is configured for bucket "my-tfstate-gcs-bucket" with <ConfigurationDetail>
    When I write a new Terraform state "S1" to the backend for workspace "default"
    Then the operation should succeed
    And if CSEK encryption is used, the object in GCS should be stored with customer-supplied encryption
    And if KMS encryption is used, the object in GCS should be stored encrypted with the specified KMS key
    And when I read the state from the backend for workspace "default"
    Then the retrieved state should be equal to "S1"
    And when I list workspaces (states)
    Then the list should include "default" (and others based on prefix structure if applicable)
    When I delete the state for workspace "default"
    Then the operation should succeed
    And reading the state again for "default" should indicate it's not found or is empty

    Examples:
      | CaseDescription        | ConfigurationDetail                                                                 |
      | Default config         | no prefix, no encryption                                                            |
      | With prefix            | prefix "projectA/envX", no encryption                                               |
      | With CSEK encryption   | encryption_key "base64_encoded_csek_key", no prefix                                 |
      | With KMS encryption    | kms_encryption_key "gcp_kms_key_resource_id", no prefix                             |
      # Note: Step definition will need to set up KMS key and GCS SA permissions for KMS test case

  Scenario: Automatic State Initialization for New Workspace in GCS
    Given the GCS backend is configured for bucket "my-tfstate-gcs-bucket" and prefix "dev_states/"
    And the GCS object "dev_states/new_workspace.tfstate" does not initially exist in the bucket
    When the state manager is requested for the "new_workspace" workspace
    Then the operation should succeed
    And an empty Terraform state should be written to the GCS object "dev_states/new_workspace.tfstate"
    And this initial empty state should be persisted
    And the state object should have been locked and then unlocked during this initialization

  Scenario: Cannot Delete Default Workspace with GCS Backend
    Given the GCS backend is configured
    When I attempt to delete the "default" workspace
    Then the operation should fail
    And the error message should contain "cowardly refusing to delete the \"default\" state"

  Scenario: State Locking and Unlocking with GCS Backend
    Given two GCS backend instances "B1" and "B2" configured for the same bucket and state object path
    When "B1" acquires a lock on the state
    Then "B1" should successfully hold the lock
    And when "B2" attempts to acquire a lock on the same state
    Then "B2" should fail to acquire the lock
    When "B1" releases its lock
    Then the operation should succeed
    And when "B2" attempts to acquire a lock on the state again
    Then "B2" should successfully acquire the lock

  Scenario: Force Unlocking State with GCS Backend
    Given a GCS backend instance "B1" configured for a state object
    And another process "ExternalLockHolder" has locked the state object in GCS
    When "B1" attempts to force unlock the state
    Then the force unlock operation should succeed
    And when "B1" attempts to acquire a lock on the state
    Then "B1" should successfully acquire the lock

```

Notes:
*   The "GCS Backend Credential Resolution" scenario captures the precedence tested in `TestAccBackendConfig_credentials`.
*   The "Core State Operations" scenario outline covers different configurations like prefix and encryption types. The step definitions will need to handle setting up the GCS bucket, and for KMS, setting up the KMS key and IAM permissions for the GCS service account.
*   Locking scenarios are standard.

This covers `backend_test.go` for the GCS backend.

Next is `internal/backend/remote-state/gcs/path_or_contents_test.go`.
