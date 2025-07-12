# Metadata:
# Covers: internal/backend/remote-state/s3/backend_complete_test.go
# TestFunctions:
# - TestBackendConfig_Authentication
# - TestBackendConfig_Authentication_AssumeRoleNested
# - TestBackendConfig_Authentication_AssumeRoleWithWebIdentity
# - TestBackendConfig_Authentication_SSO (via configtesting.SSO)
# - TestBackendConfig_Authentication_LegacySSO (via configtesting.LegacySSO)
# - TestBackendConfig_Region
# - TestStsEndpoint

Feature: S3 Backend AWS Client Authentication and Configuration Resolution
  This feature describes how the S3 remote state backend resolves AWS credentials,
  region, and service endpoints from various sources like direct configuration,
  environment variables, shared configuration/credentials files, IAM roles, and instance metadata.

  Background:
    Given a mock AWS STS service is available
    And relevant AWS environment variables are initially unset unless specified in a scenario

  Scenario Outline: AWS Credential Resolution Precedence (No AssumeRole)
    Given the S3 backend is configured with <ConfigCredentials>
    And environment variables are set as <EnvCredentials>
    And shared AWS credentials file contains <SharedFileCredentials> for profile "<Profile>"
    And EC2 Instance Metadata service is <Ec2MetadataState> (and will return <Ec2MetadataCreds> if active)
    And ECS Task Role credentials service is <EcsCredsState> (and will return <EcsCreds> if active)
    And Web Identity Token environment variables are <WebIdentityState> (and will result in <WebIdentityCreds> if active)
    When the S3 backend configures its AWS client
    Then the AWS client should use credentials corresponding to <ExpectedSource>
    And if an error is expected, it should contain "<ExpectedErrorMessage>"

    Examples:
      # Precedence: Config Static > Env Vars > Shared File Profile > Shared File Default > WebIdentity > ECS > EC2
      | ConfigCredentials             | EnvCredentials        | SharedFileCredentials (profile "myprof") | Profile | Ec2MetadataState | Ec2MetadataCreds | EcsCredsState | EcsCreds    | WebIdentityState | WebIdentityCreds | ExpectedSource        | ExpectedErrorMessage |
      | static keys "cfg_ak"/"cfg_sk" | env keys "env_ak"/"env_sk" | profile keys "prof_ak"/"prof_sk"         | myprof  | active           | ec2_creds        | active        | ecs_creds   | active           | web_id_creds     | Static Config Keys    |                      |
      | unset/empty                   | env keys "env_ak"/"env_sk" | profile keys "prof_ak"/"prof_sk"         | myprof  | active           | ec2_creds        | active        | ecs_creds   | active           | web_id_creds     | Environment Variables |                      |
      | profile="myprof"              | unset                 | profile keys "prof_ak"/"prof_sk"         | myprof  | active           | ec2_creds        | active        | ecs_creds   | active           | web_id_creds     | Shared Profile "myprof"|                      |
      | unset/empty                   | AWS_PROFILE="myprof"  | profile keys "prof_ak"/"prof_sk"         | myprof  | active           | ec2_creds        | active        | ecs_creds   | active           | web_id_creds     | Shared Profile "myprof" (via env) |               |
      | unset/empty                   | unset                 | default keys "def_ak"/"def_sk"           | default | active           | ec2_creds        | active        | ecs_creds   | active           | web_id_creds     | Shared Default Profile|                      |
      | unset/empty                   | unset                 | no profile match                         | (any)   | inactive         |                  | inactive      |             | active           | web_id_creds     | Web Identity Token    |                      |
      | unset/empty                   | unset                 | no profile match                         | (any)   | inactive         |                  | active        | ecs_creds   | inactive         |                  | ECS Task Role         |                      |
      | unset/empty                   | unset                 | no profile match                         | (any)   | active           | ec2_creds        | inactive      |             | inactive         |                  | EC2 Instance Metadata |                      |
      | unset/empty                   | unset                 | no profile match                         | (any)   | inactive         |                  | inactive      |             | inactive         |                  | (None Found)          | "No valid credential sources found" |
      | skip_credentials_validation=true, skip_metadata_api_check=true | (any) | (any)                   | (any)   | active           | (any)            | active        | (any)       | active           | (any)            | (None Found)          | "No valid credential sources found" | # Skips prevent fallback

  Scenario Outline: AWS Credential Resolution with AssumeRole
    Given the S3 backend is configured with base credentials from <BaseCredentialSource>
    And an 'assume_role' block with role_arn "<RoleARN>", session_name "<SessionName>", and other options <AssumeRoleOptions>
    When the S3 backend configures its AWS client
    Then the AWS client should attempt to assume role "<RoleARN>" using the base credentials
    And the final credentials used should be the assumed role credentials (e.g., "assumed_role_ak"/"assumed_role_sk")
    And if assume role fails (e.g. STS returns error), an error diagnostic should be produced containing "Cannot assume IAM Role"

    Examples:
      | BaseCredentialSource        | RoleARN              | SessionName        | AssumeRoleOptions                                           |
      | static keys "base_ak"/"base_sk" | "arn:aws:iam::123:role/S3Role" | "TerraformS3Backend" | duration="1h", external_id="ext123"                         |
      | environment variables       | "arn:aws:iam::123:role/S3Role" | "TerraformS3Backend" | policy="{...}", tags={"Dept":"Eng"}, transitive_tag_keys=["Dept"] |
      | EC2 instance metadata       | "arn:aws:iam::123:role/S3Role" | "TerraformS3Backend" | source_identity="user1"                                     |
      | shared credentials profile "base_profile" | "arn:aws:iam::123:role/S3Role" | "TerraformS3Backend" |                                                             |

  Scenario Outline: AWS Credential Resolution with AssumeRoleWithWebIdentity
    Given the S3 backend is configured with an 'assume_role_with_web_identity' block:
      | role_arn           | "<RoleARN>"      |
      | session_name       | "<SessionName>"  |
      | web_identity_token | "<TokenValue>"   | # Can be direct value or empty if file is used
      | web_identity_token_file | "<TokenFilePath>"| # Can be path or empty if direct value is used
      | duration           | "<Duration>"     |
      | policy             | "<Policy>"       |
    And relevant Web Identity Token environment variables are <WebIdentityEnvState>
    When the S3 backend configures its AWS client
    Then the AWS client should attempt to assume role "<RoleARN>" using the web identity token
    And the final credentials used should be the assumed role with web identity credentials
    And if assume role with web identity fails, an error diagnostic should be produced
    And if token configuration is invalid (e.g., both token and file, or neither), a validation error should occur

    Examples: # Simplified, actual test has more precedence checks
      | RoleARN              | SessionName     | TokenValue     | TokenFilePath        | Duration | Policy | WebIdentityEnvState |
      | "arn:aws:iam::123:role/WebRole" | "TFWebSession"  | "direct_token" |                      | "1h"     | "{}"   | unset               |
      | "arn:aws:iam::123:role/WebRole" | "TFWebSession"  |                | "/path/to/token.jwt" |          |        | AWS_WEB_IDENTITY_TOKEN_FILE set to different file | # Config file takes precedence over env var
      | "arn:aws:iam::123:role/WebRole" | "TFWebSession"  |                |                      |          |        | AWS_WEB_IDENTITY_TOKEN_FILE set to "/path/env_token.jwt" | # Env var used

  Scenario: AWS SSO Credential Configuration
    Given the S3 backend is configured to use an AWS SSO profile "<SSOProfileName>"
    And the shared AWS config file defines "<SSOProfileName>" with sso_start_url, sso_region, sso_account_id, sso_role_name
    When the S3 backend configures its AWS client
    Then the AWS client should use credentials obtained via the SSO token provider for "<SSOProfileName>"
    # Note: Actual SSO flow involves browser/CLI interaction, test mocks this.

  Scenario Outline: AWS Region Resolution Precedence
    Given the S3 backend is configured with region "<ConfigRegion>"
    And environment variable "AWS_REGION" is set to "<EnvAwsRegion>"
    And environment variable "AWS_DEFAULT_REGION" is set to "<EnvAwsDefaultRegion>"
    And shared AWS config file profile "default" has region "<SharedConfigRegion>" (if applicable)
    And EC2 Instance Metadata service would return region "<IMDSRegion>" (if applicable)
    When the S3 backend configures its AWS client
    Then the resolved AWS region for the client should be "<ExpectedRegion>"

    Examples: # Precedence: Config > AWS_REGION > AWS_DEFAULT_REGION > SharedConfig > IMDS (though shared/IMDS not directly used by this backend's code)
      | ConfigRegion | EnvAwsRegion | EnvAwsDefaultRegion | SharedConfigRegion | IMDSRegion | ExpectedRegion |
      | us-west-1    | us-east-1    | us-west-2           | (any)              | (any)      | us-west-1      |
      |              | us-east-1    | us-west-2           | (any)              | (any)      | us-east-1      |
      |              |              | us-west-2           | (any)              | (any)      | us-west-2      |
      # Note: S3 backend code appears to primarily use config and direct env vars for region, SDK handles deeper fallback.

  Scenario Outline: AWS STS Endpoint Resolution Precedence
    Given the S3 backend is configured with STS endpoint "<ConfigStsEndpoint>", generic endpoints.sts "<ConfigEndpointsSts>", and legacy sts_endpoint "<ConfigLegacyStsEndpoint>"
    And environment variable "AWS_ENDPOINT_URL_STS" is set to "<EnvServiceSts>"
    And environment variable "AWS_STS_ENDPOINT" (legacy) is set to "<EnvLegacySts>"
    And environment variable "AWS_ENDPOINT_URL" (global) is set to "<EnvGlobal>"
    And shared AWS config file profile "default" has services.sts.endpoint_url "<SharedServiceSts>" and global endpoint_url "<SharedGlobalSts>"
    When the S3 backend configures its AWS client for an STS operation (e.g., AssumeRole)
    Then the STS endpoint used should be "<ExpectedStsEndpoint>"

    Examples: # Precedence: Config_STS_Endpoint > Config_Endpoints_STS > Env_AWS_ENDPOINT_URL_STS > Env_AWS_STS_ENDPOINT > Env_AWS_ENDPOINT_URL > SharedConfig_Service_STS > SharedConfig_Global_STS
      | ConfigStsEndpoint | ConfigEndpointsSts | ConfigLegacyStsEndpoint | EnvServiceSts    | EnvLegacySts     | EnvGlobal        | SharedServiceSts | SharedGlobalSts  | ExpectedStsEndpoint |
      | "cfg_sts.com"     | "cfg_ep_sts.com"   | "cfg_leg_sts.com"       | "env_srv_sts.com"| "env_leg_sts.com"| "env_glob_sts.com" | "shr_srv_sts.com"| "shr_glob_sts.com" | "cfg_sts.com"       |
      |                   | "cfg_ep_sts.com"   | "cfg_leg_sts.com"       | "env_srv_sts.com"| "env_leg_sts.com"| "env_glob_sts.com" | "shr_srv_sts.com"| "shr_glob_sts.com" | "cfg_ep_sts.com"    |
      |                   |                    |                         | "env_srv_sts.com"| "env_leg_sts.com"| "env_glob_sts.com" | "shr_srv_sts.com"| "shr_glob_sts.com" | "env_srv_sts.com"   |
      # ... more combinations to show full precedence

  Scenario: S3 Backend Fails if No Valid AWS Credentials Found
    Given the S3 backend is configured with bucket "b", key "k", region "r"
    And no static credentials are in the config
    And no relevant AWS environment variables for credentials are set
    And no shared credentials/config files exist or they contain no valid credentials
    And EC2 IMDS and ECS Task Role services are unavailable or provide no credentials
    And Web Identity Token mechanisms are not configured or fail
    When the S3 backend attempts to configure its AWS client
    Then the configuration should fail
    And the error message should indicate "No valid credential sources found" or equivalent from AWS SDK

  Scenario: S3 Backend Fails on AWS Account ID Validation
    Given the S3 backend is configured with bucket "b", key "k", region "r"
    And static credentials are provided that result in AWS Account ID "999988887777"
    And the backend configuration includes forbidden_account_ids = ["999988887777"]
    When the S3 backend attempts to configure its AWS client and validate account ID
    Then the configuration should fail
    And the error message should contain "is forbidden" or "Account ID is not allowed"

  Scenario: S3 Backend Fails with Invalid SSE-C Key Format
    Given the S3 backend is configured with bucket "b", key "k", region "r"
    And sse_customer_key = "this-is-not-base64"
    When the S3 backend attempts to configure its AWS client
    Then the configuration should fail
    And the error message should contain "sse_customer_key must be base64 encoded" or "illegal base64 data"

```

Notes:
*   This is a highly complex area. The BDD aims to capture the *precedence* of different configuration sources for credentials, region, and STS endpoint.
*   Placeholders like `<ConfigCredentials>`, `<EnvCredentials>`, etc., will need to be translated by step definitions into specific map[string]any for config or env var setups.
*   `(any)` means the value doesn't matter for that specific test of precedence. `unset` means the env var is not set.
*   The "ExpectedSource" for credentials helps verify which method won.
*   Mocking for EC2/ECS/WebIdentity/SSO and STS calls is assumed in the `Given` steps.
*   The region and STS endpoint scenarios simplify a bit, as the S3 backend code itself might not implement the full SDK fallback chain for these, but relies on the SDK to do so once base credentials and minimal config are passed. The BDD reflects what the backend code *directly* influences or checks.

This is a large feature. Next is `internal/backend/remote-state/s3/backend_test.go`.
