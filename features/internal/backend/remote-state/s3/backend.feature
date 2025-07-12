# Metadata:
# Covers: internal/backend/remote-state/s3/backend_test.go and parts of backend_complete_test.go relevant to S3 config
# TestFunctions: TestBackendConfig_original, _withLockfile, _multiLock, _InvalidRegion, _RegionEnvVar, _DynamoDBEndpoint, _IAMEndpoint, _S3Endpoint, _EC2MetadataEndpoint, _PrepareConfigValidation, _PrepareConfigWithEnvVars, _Proxy, _AssumeRole, _CoerceValue
# TestFunctions: TestBackendBasic, TestBackendLocked, TestBackendLockedWithFile, TestBackend_LockFileCleanupOnDynamoDBLock, TestBackend_LockDeletedOutOfBand, TestBackend_KmsKeyId, TestBackend_ACL, TestBackendExtraPaths, TestBackendPrefixInWorkspace, TestBackendRestrictedRoot_Default, TestBackendRestrictedRoot_NamedPrefix, TestBackendWrongRegion, TestBackendS3ObjectLock

Feature: AWS S3 Remote State Backend
  This feature describes the behavior of the AWS S3 remote state backend, including its
  extensive configuration options for authentication, encryption, locking (S3 object or DynamoDB),
  endpoints, and core state operations.

  Background:
    Given an AWS environment is available and configured for testing (credentials, region)
    And an S3 bucket named "my-tfstate-s3-bucket" is available in region "us-west-2"
    And a DynamoDB table named "my-tf-lock-table" is available in region "us-west-2" (for relevant scenarios)

  Scenario Outline: S3 Backend Configuration Validation and Defaults
    Given the S3 backend is configured with <ConfigurationDetail>
    And relevant AWS environment variables are <EnvVarState>
    When the backend configuration is prepared and then configured by Terraform
    Then the operation should <Outcome>
    And if it fails, the error diagnostic summary should contain "<ExpectedErrorSummary>" and detail should contain "<ExpectedErrorDetailPart>"
    And if successful, the backend instance should reflect <ExpectedSetting>

    Examples:
      # Required fields and basic validation
      | ConfigurationDetail                                      | EnvVarState | Outcome | ExpectedErrorSummary          | ExpectedErrorDetailPart                                 | ExpectedSetting             |
      | missing 'bucket'                                         |             | fail    | "Required attribute isورا missing" | "The \"bucket\" attribute is required."                 |                             |
      | missing 'key'                                            |             | fail    | "Required attribute isورا missing" | "The \"key\" attribute is required."                    |                             |
      | missing 'region' (and no AWS_REGION/AWS_DEFAULT_REGION)  |             | fail    | "Missing region value"        | "\"region\" attribute or .* environment variables must be set." |                             |
      | bucket="", key="k", region="r"                           |             | fail    | "Invalid Value"               | "cannot be empty or all whitespace"                     |                             |
      | bucket="b", key="/lead", region="r"                      |             | fail    | "Invalid Value"               | "must not start or end with \"/\""                      |                             |
      | bucket="b", key="trail/", region="r"                     |             | fail    | "Invalid Value"               | "must not start or end with \"/\""                      |                             |
      | bucket="b", key="d//s", region="r"                       |             | fail    | "Invalid Value"               | "must not contain \"//\""                               |                             |
      | workspace_key_prefix="/lead", bucket="b", key="k", region="r" |           | fail    | "Invalid Value"               | "must not start or end with \"/\""                      |                             |
      # Encryption conflicts and requirements
      | kms_key_id="kms", sse_customer_key="csek", bucket="b", key="k", region="r" |       | fail    | "Invalid Attribute Combination" | "Only one of kms_key_id, sse_customer_key can be set."  |                             |
      | kms_key_id="$%wrongkey", bucket="b", key="k", region="r" |               | fail    | "Invalid KMS Key ID"          | 'Value must be a valid KMS Key ID, got "$%wrongkey"'    |                             |
      | kms_key_id="arn:aws:lamda:foo:bar:key/xyz", bucket="b", key="k", region="r" |     | fail    | "Invalid KMS Key ARN"         | 'Value must be a valid KMS Key ARN, got "arn:aws:lamda:foo:bar:key/xyz"' |                             |
      | assume_role={policy="\"../file.json\""}, bucket="b", key="k", region="r" |      | fail    | "Invalid IAM Policy Document" | "looks like a filename, please pass the contents"       |                             |
      | assume_role={policy="\"{\\\"Version\\\":\\\"...\\\"}\""}, bucket="b", key="k", region="r" | | fail  | "Invalid IAM Policy Document" | "policy document may have been double-encoded"          |                             |
      | assume_role={duration="bad-duration"}, bucket="b", key="k", region="r" |        | fail    | "Invalid Duration"            | "cannot be parsed as a duration"                        |                             |
      | endpoints={s3="incomplete.url"}, bucket="b", key="k", region="r" |            | warning | "Legacy S3 Endpoint URL"      | "uses an incomplete URL"                                |                             | # This validation emits a warning
      | endpoints={s3="ftp://bad.scheme"}, bucket="b", key="k", region="r" |            | fail    | "Invalid S3 Endpoint URL"       | "must be http or https"                                 |                             |
      | assume_role={external_id="a"}, bucket="b", key="k", region="r"    |            | fail    | "Invalid Value Length"        | "Length must be between 2 and 1224"                     |                             | # external_id too short
      | assume_role={session_name="bad!"}, bucket="b", key="k", region="r"|            | fail    | "Invalid Value"               | "Value can only contain letters, numbers, or =,.@/-"    |                             |
      | assume_role={policy_arns=["bad_arn"]}, bucket="b", key="k", region="r"|         | fail    | "Invalid ARN"                 | "cannot be parsed as an ARN"                            |                             |
      | ec2_metadata_service_endpoint_mode="IPv5", bucket="b", key="k", region="r"|    | fail    | "Invalid Value"               | "Value must be one of [IPv4, IPv6]"                     |                             |
      | retry_mode="non_standard", bucket="b", key="k", region="r"        |            | fail    | "Invalid Value"               | "unsupported retry mode"                                |                             | # Error from aws.ParseRetryMode
      # Auth and endpoint config (covered more in backend_auth_config.feature, but basic checks here)
      | region="invalid-region", bucket="b", key="k", skip_creds_validation=true |       | fail    | "Invalid region value"        | "Invalid AWS Region: invalid-region"                    |                             |
      | region="us-east-1", bucket="b", key="k", skip_region_validation=true, skip_creds_validation=true | | succeed |                               |                                                         | region is "us-east-1"       |
      # Defaults
      | bucket="b", key="k", region="r"                          |             | succeed |                               | encrypt=false, use_lockfile=false (DynamoDB default if table specified) |                             |

  Scenario Outline: S3 Backend State and Lock File Path Construction
    Given the S3 backend is configured with bucket "my-bucket", key "<BaseKey>", and workspace_key_prefix "<WorkspacePrefix>"
    When the S3 object path for workspace "<WorkspaceName>" is determined
    Then the state file path should be "<ExpectedStatePath>"
    And if S3 object locking is used, the lock file path should be "<ExpectedLockPath>"

    Examples: # Based on keyEnv() logic
      | BaseKey             | WorkspacePrefix | WorkspaceName | ExpectedStatePath                   | ExpectedLockPath                        |
      | terraform.tfstate   |                 | default       | terraform.tfstate                   | terraform.tfstate.lock                  |
      | project/state.json  |                 | default       | project/state.json                  | project/state.json.lock                 |
      | terraform.tfstate   | env             | dev           | env/dev/terraform.tfstate           | env/dev/terraform.tfstate.lock          |
      | project/state.json  | teamA/projectX  | prod          | teamA/projectX/prod/project/state.json | teamA/projectX/prod/project/state.json.lock |
      | tf.state            | my              | my-workspace  | my/my-workspace/tf.state            | my/my-workspace/tf.state.lock           | # workspace name contains prefix

  Scenario Outline: Core State Operations with S3 Backend (<CaseDescription>)
    Given the S3 backend is configured for bucket "my-tfstate-s3-bucket", key "state/app.tfstate", region "us-west-2", and <SpecificConfig>
    When I write a new Terraform state "S1" to the backend for workspace "default"
    Then the operation should succeed
    And specific S3 object properties should reflect <ExpectedProperties> (e.g., encryption, ACL)
    And when I read the state from the backend for workspace "default"
    Then the retrieved state should be equal to "S1"
    And when I list workspaces (states)
    Then the list should include "default" (and others based on workspace_key_prefix)
    When I delete the state for workspace "default"
    Then the operation should succeed

    Examples:
      | CaseDescription                       | SpecificConfig                                                                      | ExpectedProperties                                     |
      | Default (no encryption, DynamoDB lock)  | dynamodb_table="my-tf-lock-table"                                                   | Standard S3 properties                                 |
      | SSE-S3 Encryption (encrypt=true)      | encrypt=true, dynamodb_table="my-tf-lock-table"                                     | ServerSideEncryption: AES256                           |
      | SSE-KMS Encryption                    | kms_key_id="arn:aws:kms:...", dynamodb_table="my-tf-lock-table"                       | ServerSideEncryption: aws:kms, KMSKeyId set            |
      | SSE-C Encryption                      | sse_customer_key="base64key", sse_customer_key_sha256="sha", dynamodb_table="locktbl" | ServerSideEncryption: AES256-SSE-C (headers set)     |
      | Custom ACL                            | acl="bucket-owner-full-control", dynamodb_table="locktbl"                           | ACL: bucket-owner-full-control                         |
      | S3 Object Locking (use_lockfile=true) | use_lockfile=true                                                                   | Locking uses S3 object, not DynamoDB                   |
      | S3 Object Lock enabled on Bucket      | use_lockfile=true (bucket has Object Lock Compliance)                               | State objects have Object Lock, locking uses S3 object |

  Scenario Outline: S3 Backend Locking Mechanism (<LockingMechanism> via <LockTableOrFile>)
    Given two S3 backend instances "B1" and "B2" configured for the same S3 state object and using <LockingMechanism>
    When "B1" acquires a lock on the state
    Then "B1" should successfully hold the lock
    And when "B2" attempts to acquire a lock on the same state
    Then "B2" should fail to acquire the lock
    When "B1" releases its lock
    Then the operation should succeed
    And when "B2" attempts to acquire a lock on the state again
    Then "B2" should successfully acquire the lock

    Examples:
      | LockingMechanism          | LockTableOrFile                                     |
      | DynamoDB                  | dynamodb_table="my-tf-lock-table"                   |
      | S3 Object Lock File       | use_lockfile=true                                   |
      | S3 Object Lock File (S3 Object Lock Bucket COMPLIANCE) | use_lockfile=true, S3 Bucket has Object Lock COMPLIANCE |
      | S3 Object Lock File (S3 Object Lock Bucket GOVERNANCE)| use_lockfile=true, S3 Bucket has Object Lock GOVERNANCE |

  Scenario: Workspace Listing with Restricted Root Access but Accessible Default Prefix
    Given the S3 backend is configured with bucket "my-bucket", key "state.tf" and the default workspace_key_prefix "env:"
    And the S3 bucket policy denies s3:ListObjects at the bucket root ("") but allows listing under "env/"
    And S3 object "env/default/state.tfstate" exists (for default workspace)
    When I list workspaces
    Then the operation should succeed (or log a warning about restricted listing)
    And the list of workspaces should contain "default"
    And the list of workspaces may not contain other workspaces if full listing was prevented

  Scenario: Automatic State Initialization for New Workspace in S3
    Given the S3 backend is configured for bucket "my-s3-bucket", key "project/app.tfstate", and workspace_key_prefix "workspaces"
    And the S3 object "workspaces/new_qa_env/project/app.tfstate" does not initially exist in the bucket
    When the state manager is requested for the "new_qa_env" workspace
    Then the operation should succeed
    And an empty Terraform state should be written to the S3 object "workspaces/new_qa_env/project/app.tfstate"
    And this initial empty state should be persisted
    And the state object should have been locked and then unlocked during this initialization

  Scenario: State Integrity Check with S3 Backend using DynamoDB MD5
    Given the S3 backend is configured with bucket "b" and dynamodb_table "lock_table" for MD5 checksums
    And state "S1" with MD5 "M1" is stored in S3 and its MD5 "M1" is in DynamoDB
    When I read the state from the backend
    Then the operation should succeed and retrieve "S1"

  Scenario: State Integrity Check - MD5 Mismatch with S3 Backend
    Given the S3 backend is configured with bucket "b" and dynamodb_table "lock_table"
    And state "S_corrupted" is in S3, but DynamoDB has MD5 "M_valid" for state "S_valid"
    And consistency retry attempts are minimal
    When I attempt to read the state from the backend
    Then the operation should fail with a "bad checksum" error

  Scenario: State Integrity Check - Eventual Consistency Resolution with S3 Backend
    Given the S3 backend is configured with bucket "b", dynamodb_table "lock_table", and consistency retries
    And initially, state "S_old" is in S3, but DynamoDB has MD5 "M_new" for state "S_new"
    And during the Get operation's retry window, the S3 object is updated to "S_new"
    When I read the state from the backend
    Then the operation should eventually succeed and retrieve "S_new"

  Scenario: S3 Client Behavior with skip_s3_checksum Option
    Given the S3 backend is configured with bucket "b" and skip_s3_checksum is <SkipChecksumFlag>
    When the client prepares to upload state data to S3
    Then the underlying S3 PutObject request should <ChecksumHeaderExpectation> the "x-amz-sdk-checksum-algorithm" header set to "SHA256"

    Examples:
      | SkipChecksumFlag | ChecksumHeaderExpectation |
      | true             | not include               |
      | false            | include                   |
      | (not set)        | include                   | # Default is false

  Scenario: S3 Lock File Cleanup when DynamoDB Lock is Primary and S3 Lock Fails
    Given an S3 backend configured to use dynamodb_table "my-tf-lock-table" (primary) AND use_lockfile=true (secondary)
    And "ClientA" acquires the DynamoDB lock for the state object
    When "ClientB" (misconfigured or older) attempts to acquire an S3 object lock for the same state (which would normally succeed if DynamoDB wasn't primary) but fails because DynamoDB is already locked by ClientA
    Then the S3 object lock file potentially created by "ClientB" during its failed attempt should be cleaned up (does not exist)

  Scenario: S3 Backend Behavior with Restricted S3 Bucket (ListObjects Denied at Root)
    Given the S3 backend is configured with bucket "restricted-bucket" and key "project/state.tfstate"
    And the S3 bucket policy denies s3:ListObjects at the bucket root but allows for "default_workspace_prefix/"
    When the backend lists workspaces (default workspace_key_prefix is "default_workspace_prefix")
    Then the operation should succeed (by listing within the allowed prefix)
    And should find the "default" workspace (if state exists at "default_workspace_prefix/default/project/state.tfstate")

  Scenario: S3 Backend Error with Incorrect Region
    Given the S3 backend is configured for region "us-east-1"
    And the S3 bucket "my-bucket-in-us-west-2" actually exists in "us-west-2"
    When the backend attempts to access the state in "my-bucket-in-us-west-2"
    Then the operation should fail
    And the error message should indicate a bucket region mismatch, specifying expected "us-east-1" and found "us-west-2"

```

Notes:
*   This combines aspects from `backend_test.go` (generic state/lock tests, specific S3 options like encryption, ACL, workspace paths) and the configuration validation from `backend_complete_test.go`.
*   Authentication details are largely deferred to `s3/backend_auth_config.feature`.
*   Endpoint configurations are also more detailed in `backend_auth_config.feature`.
*   The `(any)` and other placeholders need careful handling by step definitions.
*   Specific S3 object properties (encryption type, ACL) resulting from config are checked.
*   S3 Object Lock scenarios are included.

This is a large and complex backend.

Next is `internal/backend/remote-state/s3/client_test.go`.
