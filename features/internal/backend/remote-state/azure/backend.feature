# Metadata:
# Covers: internal/backend/remote-state/azure/backend_test.go
# TestFunctions:
# - TestBackendConfig
# - TestAccBackendAccessKeyBasic (and other TestAcc scenarios covering different auth methods)
# - TestAccBackendAccessKeyLocked (and other locking scenarios)
# Note: TestBackend_impl is a compile-time check.
# Note: Relies on generic backend.TestBackendStates, TestBackendStateLocks, TestBackendStateForceUnlock suites.

Feature: Azure Blob Storage Remote State Backend
  This feature describes the behavior of the Azure Blob Storage (azurerm) remote state backend,
  including configuration, authentication, state operations, and locking.

  Background:
    Given an Azure Blob Storage account and container are available for testing
    And the backend is configured with:
      | storage_account_name | "myteststorageacc" |
      | container_name       | "tfstatecontainer" |
      | key                  | "terraform.tfstate"|
      | environment          | "AzurePublicCloud" | # or appropriate test environment

  Scenario: Basic Backend Configuration Parsing
    Given the Azure backend configuration:
      | storage_account_name | "tfaccount"   |
      | container_name       | "tfcontainer" |
      | key                  | "state"       |
      | snapshot             | false         |
      | access_key           | "encoded_key" | # Base64 encoded
    When the backend configuration is prepared and applied
    Then the backend instance should have container_name "tfcontainer"
    And key_name "state"
    And snapshotting disabled

  Scenario Outline: State Operations with <AuthMethod> Authentication
    Given Azure Blob Storage is accessible using <AuthMethod> with necessary credentials
    And the backend is configured for <AuthMethod>
    When I write a new Terraform state "S1" to the backend
    Then the operation should succeed
    And when I read the state from the backend
    Then the retrieved state should be equal to "S1"
    And when I list workspaces (states)
    Then the list should include the key for "S1" (e.g., "terraform.tfstate" or based on workspace)
    When I delete the state for workspace "default" (or key for "S1")
    Then the operation should succeed
    And reading the state again should indicate it's not found or is empty

    Examples:
      | AuthMethod                                      |
      | Storage Account Access Key                      |
      | SAS Token                                       |
      | GitHub Actions OIDC                             |
      | Azure DevOps Pipelines OIDC                     |
      | Azure AD (Service Principal with Client Secret) | # Covers use_azuread_auth=true
      | Managed Service Identity (MSI)                  |
      | Service Principal with Client Certificate       |

  Scenario Outline: State Locking and Unlocking with <AuthMethod> Authentication
    Given Azure Blob Storage is accessible using <AuthMethod> with necessary credentials
    And two Azure backend instances "B1" and "B2" are configured for the same state blob using <AuthMethod>
    When "B1" acquires a lock on the state with lock info (ID "lock-B1", User "UserA")
    Then "B1" should successfully hold the lock
    And when "B2" attempts to acquire a lock on the same state
    Then "B2" should fail to acquire the lock due to it being held by "UserA"
    When "B1" releases its lock "lock-B1"
    Then the operation should succeed
    And when "B2" attempts to acquire a lock on the state again
    Then "B2" should successfully acquire the lock

    Examples:
      | AuthMethod                                      |
      | Storage Account Access Key                      |
      | Service Principal with Client Secret            |

  Scenario Outline: Force Unlocking State with <AuthMethod> Authentication
    Given Azure Blob Storage is accessible using <AuthMethod> with necessary credentials
    And Azure backend instance "B1" is configured for the state blob using <AuthMethod>
    And another process or instance "ExternalLockHolder" has locked the state with lock ID "external-lock"
    When "B1" attempts to force unlock the state using lock ID "external-lock"
    Then the force unlock operation should succeed
    And when "B1" attempts to acquire a lock on the state
    Then "B1" should successfully acquire the lock

    Examples:
      | AuthMethod                                      |
      | Storage Account Access Key                      |
      | Service Principal with Client Secret            |

  Scenario: Attempting to Unlock State with an Invalid Lock ID (Azure Backend)
    Given the Azure backend is configured
    And the remote state in Azure Blob is locked by "UserA" with lock ID "ValidLockID"
    When an attempt is made to unlock the state using an invalid lock ID "InvalidLockID"
    Then the unlock operation should fail
    And the error message should indicate a mismatch or inability to unlock

  Scenario: Uploading State Preserves Existing Blob Metadata
    Given Azure Blob Storage is accessible
    And a state blob "terraform.tfstate" exists in container "tfstatecontainer"
    And the state blob has custom metadata "X-My-Custom-Header" set to "MyValue"
    And the Azure backend is configured to use this blob
    When I write a new Terraform state "S_new" to the backend using the Put operation
    Then the operation should succeed
    And the state blob "terraform.tfstate" in Azure should now contain the content of "S_new"
    And the state blob "terraform.tfstate" should still have the custom metadata "X-My-Custom-Header" with value "MyValue"

  Scenario Outline: Invalid Backend Authentication Configuration
    Given the Azure backend is configured with <InvalidAuthConfigDetail>
    When the backend configuration is prepared and applied (e.g., during 'terraform init')
    Then the initialization should fail
    And the error message should contain "<ExpectedErrorMessagePart>"

    Examples:
      | InvalidAuthConfigDetail                                       | ExpectedErrorMessagePart                                           |
      | an empty SAS token string                                     | "sasToken cannot be empty"                                         |
      | use_azuread_auth=true but ARM auth setup fails (e.g., bad creds)| "unable to build authorizer for Storage API"                       |
      | default auth (key listing) but no subscription_id provided    | "subscription id not specified"                                    |
      | default auth (key listing) but storage account ARM lookup fails | "retrieving commonids.StorageAccountID"                            | # Error from GetProperties
      | default auth (key listing) but listing storage keys fails     | "retrieving key for Storage Account"                               |
      # Errors from helper functions called by Configure
      | an invalid base64 encoded client_certificate                  | "could not decode client certificate data"                         |
      | oidc_token_file_path is set to a non-existent file            | "reading OIDC Token from file"                                     |
      | client_id_file_path is set to a non-existent file             | "reading Client ID from file"                                      |
      | client_secret_file_path is set to a non-existent file         | "reading Client Secret from file"                                  |
      | oidc_token is "A" and oidc_token_file_path contains "B"       | "mismatch between supplied OIDC token and supplied OIDC token file contents" |
      | client_id is "A" and client_id_file_path contains "B"         | "mismatch between supplied Client ID and supplied Client ID file contents" |
      | client_secret is "A" and client_secret_file_path contains "B" | "mismatch between supplied Client Secret and supplied Client Secret file contents" |
      | use_aks_workload_identity=true, client_id="A", env AZURE_CLIENT_ID="B" | "mismatch between supplied Client ID and that provided by AKS Workload Identity" |
      | use_aks_workload_identity=true, oidc_token="A", env AZURE_FEDERATED_TOKEN_FILE contains "B" (via env) | "mismatch between supplied OIDC token and OIDC token file contents provided by AKS Workload Identity" |
      | use_aks_workload_identity=true, tenant_id="A", env AZURE_TENANT_ID="B"   | "mismatch between supplied Tenant ID and that provided by AKS Workload Identity" |

  Scenario: Automatic State Initialization for New Workspace Key
    Given the Azure backend is configured with key "new_state_key.tfstate"
    And the Azure blob "new_state_key.tfstate" does not initially exist in the container
    When the state manager is requested for the "default" workspace (which maps to "new_state_key.tfstate")
    Then the operation should succeed
    And an empty Terraform state should be written to the blob "new_state_key.tfstate"
    And this initial empty state should be persisted
    And the state blob should have been locked and then unlocked during this initialization

  Scenario: Automatic State Initialization for New Named Workspace (Non-Default)
    Given the Azure backend is configured with base key "project.tfstate"
    And the Azure blob "project.tfstateenv:staging" does not initially exist in the container
    When the state manager is requested for the "staging" workspace
    Then the operation should succeed
    And an empty Terraform state should be written to the blob "project.tfstateenv:staging"
    And this initial empty state should be persisted
    And the state blob should have been locked and then unlocked during this initialization

  Scenario Outline: Missing Required Azure Backend Configuration Fields
    Given the Azure backend configuration is missing the required field "<MissingField>"
    When the backend configuration is prepared
    Then the preparation should produce an error diagnostic
    And the error message should indicate that "<MissingField>" is required or invalid

    Examples:
      | MissingField           |
      | storage_account_name   |
      | container_name         |
      | key                    |

  Scenario Outline: Invalid Azure Backend Configuration Logic in Configure Method
    Given the Azure backend configuration has <ConfigurationDetail>
    When the backend is configured (Configure method is called)
    Then an error diagnostic should be produced
    And the error message should contain "<ExpectedErrorMessagePart>"

    Examples:
      | ConfigurationDetail                                                        | ExpectedErrorMessagePart                                                      |
      | no direct auth (access_key, sas_token, use_azuread_auth=false) and no resource_group_name | "One of `access_key`, `sas_token`, `use_azuread_auth` and `resource_group_name` must be specifieid" | # Typo in actual error "specifieid"
      | lookup_blob_endpoint is true and no resource_group_name                    | "`resource_group_name` is required when `lookup_blob_endpoint` is set"      |
      | environment is "invalid_cloud" and no metadata_host                        | "Failed to build environment for invalid_cloud"                             | # Error from environments.FromName
      | metadata_host is invalid (e.g., "http://bad.url")                          | "environments.FromEndpoint:"                                                | # Error from environments.FromEndpoint

```

Notes:
*   The `Background` sets up common Azure resource names.
*   The "State Operations with `<AuthMethod>` Authentication" scenario uses an outline to cover various auth methods. The step definitions would need to handle the specific configuration for each method. The actual state operations (Put, Get, List, Delete) are described at a high level, corresponding to what `backend.TestBackendStates` would test.
*   Similarly, "State Locking and Unlocking" and "Force Unlocking" use outlines for different auth methods.
*   The "Attempting to Unlock State with an Invalid Lock ID" scenario is more specific, based on `TestRemoteClient_Unlock_invalidID` which is similar to how Azure backend might behave (though the error message might differ from the generic remote client).
*   The OIDC tests (`TestAccBackendGithubOIDCBasic`, `TestAccBackendADOPipelinesOIDCBasic`) depend on specific CI environment variables. The BDD abstracts this as "Given Azure Blob Storage is accessible using GitHub Actions OIDC...".
*   The MSI test (`TestAccBackendManagedServiceIdentityBasic`) requires running in Azure. The BDD abstracts this.

This covers `backend_test.go` for the Azure backend.

Next is `internal/backend/remote-state/azure/client_test.go`.
