# Metadata:
# Covers: internal/backend/remote-state/oci/backend_test.go
# TestFunctions:
# - TestBackendBasic
# - TestBackendLocked_ForceUnlock
# - TestBackendBasic_multipart_Upload
# - TestOCIBackendConfig_PrepareConfigValidation

Feature: Oracle Cloud Infrastructure (OCI) Object Storage Remote State Backend
  This feature describes the behavior of the OCI Object Storage remote state backend,
  including configuration validation, state operations, locking, and multipart uploads.

  Background:
    Given an OCI environment is available and configured for testing (credentials, tenancy, region, compartment)
    And an OCI Object Storage bucket named "my-tfstate-oci-bucket" exists in namespace "my-namespace"

  Scenario Outline: OCI Backend Configuration Validation
    Given the OCI backend is configured with <ConfigurationDetail>
    When the backend configuration is prepared by Terraform
    Then the operation should <Outcome>
    And if it fails, the error diagnostic summary should contain "<ExpectedErrorSummary>"
    And if it fails, the error diagnostic detail should contain "<ExpectedErrorDetailPart>"

    Examples:
      | ConfigurationDetail                                     | Outcome | ExpectedErrorSummary             | ExpectedErrorDetailPart                                                                 |
      | missing 'bucket'                                        | fail    | "Required attribute isورا missing" | "The \"bucket\" attribute is required."                                                 | # Assuming backendbase errors
      | missing 'namespace'                                     | fail    | "Required attribute isورا missing" | "The \"namespace\" attribute is required."                                              |
      | key="/leading/slash"                                    | fail    | "Invalid Value"                  | 'The value must not start or end with "/" and also not contain consecutive "/"'       |
      | key="trailing/slash/"                                   | fail    | "Invalid Value"                  | 'The value must not start or end with "/" and also not contain consecutive "/"'       |
      | key="double//slash"                                     | fail    | "Invalid Value"                  | 'The value must not start or end with "/" and also not contain consecutive "/"'       |
      | workspace_key_prefix="/leadingslash"                    | fail    | "Invalid Value"                  | 'The value must not start with "/" and also not contain consecutive "/"'              |
      | kms_key_id="kms", sse_customer_key="csek"               | fail    | "Invalid Attribute Combination"  | "Only one of kms_key_id, sse_customer_key can be set."                                  |
      | sse_customer_key="csek", no sse_customer_key_sha256     | fail    | "Invalid Attribute Combination"  | "sse_customer_key and its SHA both required."                                           |
      | private_key="pk", private_key_path="/pkp"               | fail    | "Invalid Attribute Combination"  | "Only one of private_key, private_key_path can be set."                                 |
      | auth="invalid_method"                                   | fail    | "Invalid authentication method"  | "auth must be one of 'api_key' or 'instance_principal' or 'instance_principal_with_certs' or 'security_token' or 'resource_principal' or 'oke_workload_identity'" |
      | auth="instance_principal", no region, env OCI_REGION unset | fail    | "Missing region attribute required" | "The attribute \"region\" is required by the backend for instance_principal authentication." |
      | bucket="invalid!bucket@name"                            | fail    | "Invalid Value"                  | "The bucket name can only include alphanumeric characters, underscores (_), and hyphens (-)." |

  Scenario: Core State Operations with OCI Backend
    Given the OCI backend is configured for bucket "my-tfstate-oci-bucket", namespace "my-namespace", and key "default.tfstate"
    When I write a new Terraform state "S1" to the backend for workspace "default"
    Then the operation should succeed
    And when I read the state from the backend for workspace "default"
    Then the retrieved state should be equal to "S1"
    And when I list workspaces (states)
    Then the list should include "default"
    When I delete the state for workspace "default"
    Then the operation should succeed
    And reading the state again for "default" should indicate it's not found or is empty

  Scenario: State Locking and Unlocking with OCI Backend
    Given two OCI backend instances "B1" and "B2" configured for the same bucket, namespace, and key
    When "B1" acquires a lock on the state
    Then "B1" should successfully hold the lock
    And when "B2" attempts to acquire a lock on the same state
    Then "B2" should fail to acquire the lock
    When "B1" releases its lock
    Then the operation should succeed
    And when "B2" attempts to acquire a lock on the state again
    Then "B2" should successfully acquire the lock

  Scenario: Force Unlocking State with OCI Backend
    Given an OCI backend instance "B1" configured for a state object
    And another process "ExternalLockHolder" has locked the state object in OCI
    When "B1" attempts to force unlock the state
    Then the force unlock operation should succeed
    And when "B1" attempts to acquire a lock on the state
    Then "B1" should successfully acquire the lock

  Scenario: State Operations with Multipart Upload for Large States
    Given the OCI backend is configured for bucket "my-tfstate-oci-bucket", namespace "my-namespace", and key "large_state.tfstate"
    And the OCI client is forced to use small part sizes for multipart upload (e.g., 100 bytes)
    And a Terraform state "S_large" that exceeds the single part upload threshold
    When I write state "S_large" to the backend
    Then the operation should succeed (using multipart upload)
    And when I read the state from the backend
    Then the retrieved state should be equal to "S_large"

  Scenario Outline: OCI Backend Authentication Method Specific Configuration Errors
    Given the OCI backend is configured with auth type "<AuthType>" and <SpecificInvalidConfig>
    When the backend configuration is processed by Configure method
    Then the initialization should fail
    And the error message should contain "<ExpectedErrorMessagePart>"

    Examples:
      | AuthType                       | SpecificInvalidConfig                                            | ExpectedErrorMessagePart                                  |
      | api_key                        | missing user_ocid                                                | "can not get user_ocid"                                   |
      | api_key                        | missing fingerprint                                              | "can not get fingerprint"                                 |
      | api_key                        | missing private_key and private_key_path                         | "can not get private_key or private_key_path"             |
      | api_key                        | private_key_path points to unreadable file                       | "can not read private key from"                           |
      | api_key                        | private_key content is not a valid RSA key                       | "PrivateRSAKey"                                           |
      | instance_principal             | region is missing (and no env var for region)                    | "unable to determine region"                              |
      | instance_principal_with_certs  | region is missing                                                | "unable to determine region"                              |
      | instance_principal_with_certs  | leaf certificate path is invalid                                 | "can not read leaf certificate"                           |
      | instance_principal_with_certs  | leaf private key path is invalid                                 | "can not read leaf private key"                           |
      | security_token                 | region is missing                                                | "can not get region"                                      |
      | security_token                 | config_file_profile is missing                                   | "missing profile in provider block config_file_profile"   |
      | security_token                 | OCI config file or profile is invalid/missing (mocked setup)     | "could not create security token based auth config provider"|
      | resource_principal             | OCI SDK fails to get resource principal provider (mocked setup)  | "ResourcePrincipalConfigurationProvider"                  |
      | oke_workload_identity          | OCI SDK fails to get OKE provider (mocked setup)                 | "can not get oke workload indentity based auth config provider" |

  Scenario Outline: OCI Backend Retries on Specific Transient API Errors
    Given the OCI backend is configured
    And an OCI API call during a state <OperationType> operation initially fails with HTTP status <StatusCode> or a <NetworkErrorType> network error
    And subsequent API calls for the same operation will succeed after <NumberOfRetries> retries
    When I perform the state <OperationType> operation
    Then the operation should eventually succeed
    And the OCI client should have made approximately <ExpectedTotalAttempts> attempts for that API call

    Examples:
      | OperationType | StatusCode | NetworkErrorType | NumberOfRetries | ExpectedTotalAttempts |
      | Get           | 429        |                  | 1               | 2                     |
      | Put           | 500        |                  | 2               | 3                     |
      | Lock          | 503        |                  | 0               | 1                     |
      | Delete        |            | "i/o timeout"    | 1               | 2                     |

  Scenario Outline: OCI Backend Fails Without Retry on Non-Retryable API Errors
    Given the OCI backend is configured
    And an OCI API call during a state <OperationType> operation fails with HTTP status <StatusCode>
    When I perform the state <OperationType> operation
    Then the operation should fail on the first attempt
    And the error message should reflect the OCI API error with status <StatusCode>

    Examples:
      | OperationType | StatusCode |
      | Get           | 400        | # Bad Request
      | Put           | 401        | # Unauthorized
      | Lock          | 403        | # Forbidden
      # Note: 404 for Get is handled as 'state not found', not a retryable/failing error for the client.

```

Notes:
*   The "OCI Backend Configuration Validation" scenario covers the unit tests from `TestOCIBackendConfig_PrepareConfigValidation`. The error messages are based on the `tfdiags` helpers used in the Go test.
*   The "Core State Operations", "Locking", and "Force Unlocking" scenarios are standard, reflecting the use of generic test suites.
*   The "Multipart Upload" scenario captures the essence of `TestBackendBasic_multipart_Upload`. The Gherkin step `And the OCI client is forced to use small part sizes...` abstracts the `DefaultFilePartSize = 100` modification.

This covers `backend_test.go` for the OCI backend. There are no other `_test.go` files in this directory.

Next, I will analyze the non-test `.go` files in `internal/backend/remote-state/oci/`.
These are: `auth.go`, `backend.go`, `backend_state.go`, `client.go`, `constants.go`, `log.go`, `multipart_upload.go`, `retry.go`, `util.go`.

I'll start with `auth.go`.
