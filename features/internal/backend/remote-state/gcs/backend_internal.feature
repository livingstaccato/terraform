# Metadata:
# Covers: internal/backend/remote-state/gcs/backend_internal_test.go
# TestFunctions:
# - TestBackendConfig_encryptionKey
# - TestBackendConfig_kmsKey
# - TestStateFile
# - TestBackendEncryptionKeyEmptyConflict

Feature: GCS Backend Internal Configuration and Path Logic
  This feature describes specific internal behaviors of the Google Cloud Storage (GCS)
  remote state backend, particularly around encryption key resolution and state/lock file path generation.

  Scenario Outline: CSEK Encryption Key Resolution for GCS Backend
    Given the GCS backend is configured with bucket "my-gcs-bucket"
    And the 'encryption_key' in the backend configuration is "<ConfigKeyValue>"
    And the environment variable "GOOGLE_ENCRYPTION_KEY" is set to "<EnvKeyValue>"
    When the backend configuration is processed
    Then the resolved CSEK encryption key (base64 decoded) should be "<ExpectedDecodedKey>"

    Examples:
      | ConfigKeyValue      | EnvKeyValue           | ExpectedDecodedKey              | Description                                         |
      |                     |                       | (nil)                           | Unset in config and ENV                             |
      | "config_key_b64"    | "env_key_b64"         | (decoded "config_key_b64")    | Config value takes precedence                       |
      |                     | "env_key_b64"         | (decoded "env_key_b64")         | Only ENV is set                                     |
      | ""                  | "env_key_b64"         | (decoded "env_key_b64")         | Config is empty string, ENV is used                 |
      # Note: "config_key_b64" and "env_key_b64" are placeholders for actual base64 encoded strings.
      # (nil) means the byte slice should be nil. (decoded "X") means the result of base64 decoding X.

  Scenario Outline: KMS Encryption Key Resolution for GCS Backend
    Given the GCS backend is configured with bucket "my-gcs-bucket"
    And the 'kms_encryption_key' in the backend configuration is "<ConfigKeyValue>"
    And the environment variable "GOOGLE_KMS_ENCRYPTION_KEY" is set to "<EnvKeyValue>"
    When the backend configuration is processed
    Then the resolved KMS key name should be "<ExpectedKmsKeyName>"

    Examples:
      | ConfigKeyValue      | EnvKeyValue           | ExpectedKmsKeyName    | Description                                         |
      |                     |                       | ""                    | Unset in config and ENV                             |
      | "config_kms_key"    | "env_kms_key"         | "config_kms_key"      | Config value takes precedence                       |
      |                     | "env_kms_key"         | "env_kms_key"         | Only ENV is set                                     |
      | ""                  | "env_kms_key"         | "env_kms_key"         | Config is empty string, ENV is used                 |

  Scenario Outline: State and Lock File Object Key Construction in GCS
    Given the GCS backend is configured with prefix "<Prefix>"
    When the object key for workspace "<WorkspaceName>" is determined
    Then the state file key should be "<ExpectedStateFileKey>"
    And the lock file key should be "<ExpectedLockFileKey>"

    Examples:
      | Prefix | WorkspaceName | ExpectedStateFileKey   | ExpectedLockFileKey        |
      | state  | default       | state/default.tfstate  | state/default.tflock       |
      | state  | test          | state/test.tfstate     | state/test.tflock          |
      # Note: GCS backend uses prefix/<workspace>.tfstate, unlike COS which uses prefix<workspace_prefix><key> or <workspace>/<key>

  Scenario: Conflict When Both CSEK and KMS Keys are Explicitly Empty in Configuration
    Given the GCS backend is configured with bucket "my-gcs-bucket"
    And 'encryption_key' is explicitly set to "" in the configuration
    And 'kms_encryption_key' is explicitly set to "" in the configuration
    And environment variables "GOOGLE_ENCRYPTION_KEY" and "GOOGLE_KMS_ENCRYPTION_KEY" are unset or empty
    When the backend configuration is processed
    Then an error diagnostic should be produced
    And the error message should contain "can't set both encryption_key and kms_encryption_key"

  Scenario Outline: GCS Backend Configuration Errors During Initialization
    Given the GCS backend is configured with <InitialConfiguration>
    And relevant environment variables are <EnvVarState>
    When the backend configuration is processed by Configure method
    Then the initialization should fail
    And the error message should contain "<ExpectedErrorMessagePart>"

    Examples:
      | InitialConfiguration                                 | EnvVarState        | ExpectedErrorMessagePart                                            |
      | bucket="b", encryption_key="not_base64"              | all unset          | "Error decoding encryption key"                                     |
      | bucket="b", credentials="invalid_json_string"        | all unset          | "the string provided in credentials is neither valid json nor a valid file path" |
      | bucket="b", credentials="/path/to/non_existent_file.json" | all unset          | "Error loading credentials"                                         |
      | bucket="b", impersonate_service_account="bad@sa"     | GOOGLE_CREDENTIALS set | "iam.serviceAccounts.getAccessToken"                              | # Error from impersonate
      | bucket="b", storage_custom_endpoint="http://<invalid>" | GOOGLE_CREDENTIALS set | "storage.NewClient() failed"                                      | # Error from NewClient with bad endpoint

  Scenario: GCS Backend Prefix Normalization
    Given the GCS backend is configured with bucket "my-bucket" and prefix "/leading/and/trailing/"
    When the backend configuration is processed
    Then the backend instance's internal prefix should be "leading/and/trailing/"
    Given the GCS backend is configured with bucket "my-bucket" and prefix "no_trailing"
    When the backend configuration is processed
    Then the backend instance's internal prefix should be "no_trailing/"
    Given the GCS backend is configured with bucket "my-bucket" and prefix "" (empty)
    When the backend configuration is processed
    Then the backend instance's internal prefix should be "" (empty)

```

Notes:
*   The CSEK key examples use placeholders like `"config_key_b64"` and `(decoded "config_key_b64")`. The step definition will need to handle actual base64 encoding/decoding for comparison.
*   The `TestStateFile` in GCS is simpler than COS; it seems to always use `prefix/workspace_name.tfstate`. The `key` attribute from the config is used as the *default* workspace name if not "default", or as the state file name under the prefix/workspace directory. The Gherkin example for `TestStateFile` here reflects the simpler structure shown in the Go test. I've adjusted the examples to match `TestStateFile` from `gcs/backend_internal_test.go`.
*   The "Conflict When Both CSEK and KMS Keys are Explicitly Empty" scenario covers the specific edge case tested by `TestBackendEncryptionKeyEmptyConflict`.

This covers `backend_internal_test.go` for GCS.

Next is `internal/backend/remote-state/gcs/backend_test.go`.
