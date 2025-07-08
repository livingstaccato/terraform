# Metadata:
#   Covers: internal/plugin6/grpc_provider_test.go
#   Tests:
#     - TestGRPCProvider_Configure (which tests ConfigureProvider RPC)

Feature: ConfigureProvider RPC
  As a Terraform plugin,
  I need to respond to ConfigureProvider requests
  So that Terraform core can initialize and configure me with provider-specific settings before I am used.

  Background:
    Given a configured tfplugin6 gRPC provider server
    And the provider has a defined schema for its configuration (provider_meta schema)

  Scenario: Successfully configure the provider with valid configuration
    Given the provider schema defines a required string attribute "api_token"
    And a ConfigureProvider request is made with:
      | terraform_version | "1.0.0"                         |
      | config            | `{"api_token": "secret_token"}` |
      | client_capabilities | (standard capabilities)       |
    When the ConfigureProvider RPC is called with these details
    Then the response should not contain any error diagnostics
    And the response should not contain any warning diagnostics
    And the provider should be internally configured with "api_token"

  Scenario: Configure provider with missing required attribute in configuration
    Given the provider schema defines a required string attribute "api_token"
    And a ConfigureProvider request is made with an empty config: `{}`
    And terraform_version "1.0.0" and client_capabilities
    When the ConfigureProvider RPC is called
    Then the response should contain an error diagnostic indicating "api_token" is required for provider configuration
    And the provider should not be considered successfully configured

  Scenario: Configure provider with attribute of incorrect type in configuration
    Given the provider schema defines a string attribute "api_token"
    And a ConfigureProvider request is made with config: `{"api_token": 12345}` (an integer)
    And terraform_version "1.0.0" and client_capabilities
    When the ConfigureProvider RPC is called
    Then the response should contain an error diagnostic indicating "api_token" has an incorrect type
    And the provider should not be considered successfully configured

  Scenario: Configure provider with an unknown attribute in configuration
    # Providers typically ignore unknown attributes during Configure, unlike Validate.
    # Or they might warn. The test `TestGRPCProvider_Configure` implies success if known parts are okay.
    Given the provider schema only defines an attribute "api_token"
    And a ConfigureProvider request is made with config: `{"api_token": "secret", "unknown_field": "value"}`
    And terraform_version "1.0.0" and client_capabilities
    When the ConfigureProvider RPC is called
    Then the response should not contain any error diagnostics if "api_token" is valid
    And the provider may issue a warning diagnostic for "unknown_field"
    And the provider should be internally configured with "api_token"

  Scenario: Configure provider with null or empty configuration when all attributes are optional
    Given the provider schema defines only optional attributes (e.g., "region", "timeout")
    And a ConfigureProvider request is made with a null config
    And terraform_version "1.0.0" and client_capabilities
    When the ConfigureProvider RPC is called
    Then the response should not contain any error diagnostics
    And the provider should be configured with default values or as unconfigured but valid
    And a ConfigureProvider request is made with an empty JSON object config `{}`
    When the ConfigureProvider RPC is called
    Then the response should not contain any error diagnostics
    And the provider should be configured with default values or as unconfigured but valid

  Scenario: Configure provider resulting in multiple diagnostics (errors and warnings)
    Given the provider schema defines a required "endpoint" and an optional "retries" (number)
    And a ConfigureProvider request is made with config: `{"retries": "five", "unknown_opt": "ignored"}` (missing endpoint, wrong type for retries)
    And terraform_version "1.0.0" and client_capabilities
    When ConfigureProvider RPC is called
    Then the response should contain an error diagnostic for missing "endpoint"
    And the response should contain an error diagnostic for "retries" having an incorrect type
    And the response may contain a warning diagnostic for "unknown_opt"
    And the provider should not be considered successfully configured

  Scenario: Handle gRPC error during ConfigureProvider
    Given the provider's ConfigureProvider RPC will return a gRPC error
    And a ConfigureProvider request is made
    When the ConfigureProvider RPC is called
    Then the overall operation should result in an error diagnostic reflecting the gRPC error
    And the provider should not be considered configured

  Scenario: Diagnostic message includes attribute path for configuration error
    Given the provider schema defines a string attribute "access_key"
    And a ConfigureProvider request is made with config: `{"access_key": false}` (boolean)
    When the ConfigureProvider RPC is called
    Then the response should contain an error diagnostic
    And the diagnostic's attribute path should correctly point to "access_key"

  Scenario: Provider configuration uses msgpack encoding for DynamicValue
    Given a ConfigureProvider request is made with config `{"api_token": "token_mp"}` encoded using msgpack
    And terraform_version "1.0.0" and client_capabilities
    When the ConfigureProvider RPC is called
    Then the provider should correctly decode and configure itself using the msgpack data
    And the response should not contain any error diagnostics

  Scenario: Provider configuration uses JSON encoding for DynamicValue
    Given a ConfigureProvider request is made with config `{"api_token": "token_json"}` encoded using JSON
    And terraform_version "1.0.0" and client_capabilities
    When the ConfigureProvider RPC is called
    Then the provider should correctly decode and configure itself using the JSON data
    And the response should not contain any error diagnostics

  Scenario: ConfigureProvider request includes Terraform version information
    Given a ConfigureProvider request is made with `terraform_version = "1.2.3-custom"`
    And valid configuration
    When the ConfigureProvider RPC is called
    Then the provider should receive the Terraform version "1.2.3-custom"
    And configure successfully without errors related to the version string.
    # Provider might use this for compatibility checks or enabling features.

  Scenario: ConfigureProvider request includes client capabilities
    Given a ConfigureProvider request is made with specific client capabilities (e.g., `deferral_allowed = true`, `write_only_attributes_allowed = true`)
    And valid configuration
    When the ConfigureProvider RPC is called
    Then the provider should receive these client capabilities
    And may adjust its behavior based on these capabilities (e.g. enable deferred operations if client allows)
    And configure successfully.

  Scenario: ConfigureProvider request with empty client capabilities
    Given a ConfigureProvider request is made with empty client capabilities (all flags false or message is nil/default)
    And valid configuration
    When the ConfigureProvider RPC is called
    Then the provider should receive these (default/empty) client capabilities
    And should assume standard/baseline client behavior
    And configure successfully.

  Scenario: Provider configuration includes deprecated attributes
    Given the provider schema marks an attribute "old_auth_method" as deprecated
    And a ConfigureProvider request is made with config `{"old_auth_method": "legacy_key", "current_auth": "token"}`
    When the ConfigureProvider RPC is called
    Then the provider should configure successfully if "current_auth" is valid
    And the response may contain a warning diagnostic for "old_auth_method".
    # The provider should still be usable if the deprecated attribute is valid or if new attributes suffice.

  Scenario: ConfigureProvider fails due to external reasons (e.g., cannot reach an auth service)
    # This goes beyond simple schema validation, testing provider's initialization logic.
    Given a provider that tries to validate API credentials by making an external call during ConfigureProvider
    And a ConfigureProvider request is made with config `{"api_token": "invalid_or_expired_token"}`
    When the ConfigureProvider RPC is called
    Then the response should contain an error diagnostic detailing the external failure (e.g., "API authentication failed")
    And the provider should not be considered successfully configured.

  Scenario: Re-configuring an already configured provider
    # The protocol doesn't explicitly state if ConfigureProvider can be called multiple times.
    # Assuming it can be (e.g. if config changes without full provider restart).
    Given the provider has been successfully configured with `{"api_token": "initial_token"}`
    And a new ConfigureProvider request is made with `{"api_token": "updated_token"}`
    When the ConfigureProvider RPC is called again
    Then the provider should update its internal configuration to use "updated_token"
    And the response should not contain any error diagnostics.
    # Or, if re-configuration is not supported, it should return an appropriate error.
    # Current Go test implies it's fine and overwrites.
