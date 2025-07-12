# Metadata:
# Covers: internal/backend/remote-state/oss/backend_test.go
# TestFunctions:
# - TestBackendConfig
# - TestBackendConfigWorkSpace
# - TestBackendConfigProfile
# - TestBackendConfig_invalidKey
# - TestBackend
# Note: TestBackend_impl is a compile-time check.
# Note: Relies on generic backend.TestBackendStates, TestBackendStateLocks, TestBackendStateForceUnlock suites.

Feature: Alibaba Cloud OSS Remote State Backend
  This feature describes the behavior of the Alibaba Cloud Object Storage Service (OSS)
  remote state backend, including configuration, state operations, and locking (potentially using Tablestore).

  Background:
    Given an Alibaba Cloud environment is available and configured for testing (AccessKey, SecretKey, Region)
    And an OSS bucket named "my-tfstate-oss-bucket" is available in region "cn-beijing"

  Scenario Outline: OSS Backend Configuration Parsing and Validation
    Given the OSS backend is configured with <ConfigurationDetail>
    When the backend configuration is prepared and then configured by Terraform
    Then the operation should <Outcome>
    And if successful, the backend instance should reflect <ExpectedSetting>
    And if it fails, the error message should contain "<ExpectedErrorMessagePart>"

    Examples:
      | ConfigurationDetail                                                                   | Outcome | ExpectedSetting                                                                 | ExpectedErrorMessagePart         |
      | region="cn-shanghai", bucket="b", prefix="p", key="k.tfstate"                          | succeed | region is "cn-shanghai", bucket "b", prefix "p", key "k.tfstate"                |                                  |
      | profile="myprofile" (assuming valid shared credentials for this profile)              | succeed | auth uses "myprofile"                                                           |                                  |
      | bucket="b", prefix="/invalid-prefix"                                                  | fail    |                                                                                 | "prefix must not start with '/'" |
      | bucket="b", key="/invalid.tfstate"                                                    | fail    |                                                                                 | "key can not start with '/'"     |
      | bucket="b", key="invalid.tfstate/"                                                    | fail    |                                                                                 | "key can not end with '/'"       |
      # Required fields like region, bucket, access_key_id, access_key_secret are typically from env or profile for tests
      | missing 'bucket'                                                                      | fail    |                                                                                 | "bucket" is required             |
      | missing 'region'                                                                      | fail    |                                                                                 | "region" is required             |

  Scenario: Core State Operations with OSS Backend
    Given the OSS backend is configured for bucket "my-tfstate-oss-bucket", region "cn-beijing", prefix "myproject", and key "default.tfstate"
    When I write a new Terraform state "S1" to the backend for workspace "default"
    Then the operation should succeed
    And when I read the state from the backend for workspace "default"
    Then the retrieved state should be equal to "S1"
    And when I list workspaces (states)
    Then the list should include "default" (and others based on prefix structure if applicable)
    When I delete the state for workspace "default"
    Then the operation should succeed
    And reading the state again for "default" should indicate it's not found or is empty

  Scenario: State Locking and Unlocking with OSS Backend (Potentially using Tablestore)
    Given two OSS backend instances "B1" and "B2" configured for the same bucket, region, prefix, key, and Tablestore for locking
    When "B1" acquires a lock on the state
    Then "B1" should successfully hold the lock (an entry is created in the configured Tablestore table)
    And when "B2" attempts to acquire a lock on the same state
    Then "B2" should fail to acquire the lock
    When "B1" releases its lock
    Then the operation should succeed
    And when "B2" attempts to acquire a lock on the state again
    Then "B2" should successfully acquire the lock

  Scenario: Force Unlocking State with OSS Backend using Tablestore
    Given an OSS backend instance "B1" configured for a state object and Tablestore for locking
    And another process "ExternalLockHolder" has locked the state object (entry in Tablestore)
    When "B1" attempts to force unlock the state
    Then the force unlock operation should succeed
    And when "B1" attempts to acquire a lock on the state
    Then "B1" should successfully acquire the lock

  Scenario: State Integrity Check - MD5 Match
    Given the OSS backend is configured with Tablestore for MD5 checksums
    And state "S1" with MD5 "M1" is stored in OSS and its MD5 "M1" is in Tablestore
    When I read the state from the backend
    Then the operation should succeed
    And the retrieved state should be "S1"

  Scenario: State Integrity Check - MD5 Mismatch
    Given the OSS backend is configured with Tablestore for MD5 checksums
    And state "S_corrupted" is stored in OSS
    And the MD5 "M_valid" for a different valid state "S_valid" is stored in Tablestore for this state key
    And consistency retry attempts are configured to be minimal (e.g., 0 retries, immediate timeout)
    When I attempt to read the state from the backend
    Then the operation should fail
    And the error message should contain "content of state file does not match checksum" (or similar errBadChecksumFmt)

  Scenario: State Integrity Check - Eventual Consistency Resolution
    Given the OSS backend is configured with Tablestore for MD5 checksums and consistency retries enabled
    And initially, state "S_old" is in OSS, but Tablestore has MD5 "M_new" for an updated state "S_new"
    And during the Get operation's retry window, the OSS object is updated to "S_new" (matching MD5 "M_new")
    When I read the state from the backend
    Then the operation should eventually succeed after retries
    And the retrieved state should be "S_new"

```

Notes:
*   The BDD abstracts the Alibaba Cloud SDK interactions for creating/deleting buckets and Tablestore tables.
*   The "Configuration Parsing and Validation" scenario covers basic field assignments and some validation rules (like invalid prefix/key).
*   The locking scenarios mention Tablestore as it's a common mechanism for robust locking with OSS, though OSS itself also has object-level locking capabilities that might be used. The BDD is slightly generic here to accommodate either.
*   Authentication details (AccessKey, SecretKey) are assumed to be provided via environment variables or a profile, as typical in acceptance tests.

This covers `backend_test.go` for the OSS backend.

Next is `internal/backend/remote-state/oss/client_test.go`.
