# Metadata:
#   Covers: internal/plugin6/grpc_provider_test.go
#   Tests:
#     - TestGRPCProvider_PrepareProviderConfig (which tests ValidateProviderConfig)

Feature: ValidateProviderConfig RPC
  As a Terraform plugin,
  I need to respond to ValidateProviderConfig requests
  So that Terraform core can validate the provider configuration provided by the user.

  Background:
    Given a configured tfplugin6 gRPC provider server
    And the provider has a defined schema for its configuration (provider_meta schema)

  Scenario: Successfully validate a valid provider configuration
    Given the provider schema defines a required string attribute "attr"
    And a ValidateProviderConfig request is made with configuration: `{"attr": "valid_value"}`
    When the ValidateProviderConfig RPC is called with this configuration
    Then the response should not contain any error diagnostics
    And the response should not contain any warning diagnostics

  Scenario: Validate provider configuration with missing required attribute
    Given the provider schema defines a required string attribute "attr"
    And a ValidateProviderConfig request is made with an empty configuration: `{}`
    When the ValidateProviderConfig RPC is called with this configuration
    Then the response should contain an error diagnostic indicating "attr" is required

  Scenario: Validate provider configuration with attribute of incorrect type
    Given the provider schema defines a string attribute "attr"
    And a ValidateProviderConfig request is made with configuration: `{"attr": 123}` (an integer)
    When the ValidateProviderConfig RPC is called with this configuration
    Then the response should contain an error diagnostic indicating "attr" has an incorrect type

  Scenario: Validate provider configuration with an unknown attribute
    Given the provider schema only defines an attribute "attr"
    And a ValidateProviderConfig request is made with configuration: `{"attr": "value", "unknown_attr": "another_value"}`
    When the ValidateProviderConfig RPC is called with this configuration
    Then the response should contain a warning diagnostic indicating "unknown_attr" is unexpected
    # Or an error, depending on provider's strictness. Warnings are common for this.
    And the response should not contain error diagnostics for known attributes if they are valid

  Scenario: Validate provider configuration that is null or empty
    # This assumes the provider configuration block itself is optional or has all optional attributes.
    Given the provider schema defines only optional attributes
    And a ValidateProviderConfig request is made with a null configuration
    When the ValidateProviderConfig RPC is called with this configuration
    Then the response should not contain any error diagnostics
    And a ValidateProviderConfig request is made with an empty JSON object configuration `{}`
    When the ValidateProviderConfig RPC is called with this configuration
    Then the response should not contain any error diagnostics

  Scenario: Validate provider configuration resulting in multiple diagnostics (errors and warnings)
    Given the provider schema defines a required string "req_attr" and an optional string "opt_attr"
    And a ValidateProviderConfig request is made with configuration: `{"opt_attr": 123, "unknown_attr": "foo"}` (missing req_attr, wrong type for opt_attr, unknown_attr)
    When the ValidateProviderConfig RPC is called with this configuration
    Then the response should contain an error diagnostic for missing "req_attr"
    And the response should contain an error diagnostic for "opt_attr" having an incorrect type
    And the response should contain a warning diagnostic for "unknown_attr"

  Scenario: Handle gRPC error during ValidateProviderConfig
    Given the provider's ValidateProviderConfig RPC will return a gRPC error
    And a ValidateProviderConfig request is made with some configuration
    When the ValidateProviderConfig RPC is called
    Then the overall operation should result in an error diagnostic reflecting the gRPC error

  Scenario: Validate provider configuration with complex nested structure
    Given the provider schema defines a configuration block "api_settings" with a required attribute "url"
    And a ValidateProviderConfig request is made with configuration: `{"api_settings": {"url": "http://example.com"}}`
    When the ValidateProviderConfig RPC is called with this configuration
    Then the response should not contain any error diagnostics

  Scenario: Validate provider configuration with missing required attribute in a nested block
    Given the provider schema defines a configuration block "api_settings" with a required attribute "url"
    And a ValidateProviderConfig request is made with configuration: `{"api_settings": {}}`
    When the ValidateProviderConfig RPC is called with this configuration
    Then the response should contain an error diagnostic indicating "api_settings.url" is required

  Scenario: Diagnostic message includes attribute path for validation error
    Given the provider schema defines a string attribute "config_value"
    And a ValidateProviderConfig request is made with configuration: `{"config_value": 123}`
    When the ValidateProviderConfig RPC is called
    Then the response should contain an error diagnostic
    And the diagnostic's attribute path should correctly point to "config_value"

  Scenario: Provider configuration uses msgpack encoding for DynamicValue
    Given a ValidateProviderConfig request is made with a configuration encoded using msgpack
    And the configuration is `{"attr": "valid_value"}`
    When the ValidateProviderConfig RPC is called with this msgpack encoded configuration
    Then the provider should correctly decode and validate the configuration
    And the response should not contain any error diagnostics

  Scenario: Provider configuration uses JSON encoding for DynamicValue
    Given a ValidateProviderConfig request is made with a configuration encoded using JSON
    And the configuration is `{"attr": "valid_value"}`
    When the ValidateProviderConfig RPC is called with this JSON encoded configuration
    Then the provider should correctly decode and validate the configuration
    And the response should not contain any error diagnostics

  Scenario: Validate provider configuration when no provider schema (provider_meta) is defined
    # If a provider has no configurable attributes, its provider_meta schema might be empty/nil.
    Given the provider does not define any configuration attributes (empty provider_meta schema)
    And a ValidateProviderConfig request is made with configuration: `{"some_user_value": "foo"}`
    When the ValidateProviderConfig RPC is called
    Then the response should likely contain warning diagnostics for all unexpected attributes
    # Or it might be an error if the provider expects no configuration at all.
    And a ValidateProviderConfig request is made with an empty configuration: `{}`
    When the ValidateProviderConfig RPC is called
    Then the response should not contain any error or warning diagnostics.

  Scenario: Validate provider configuration with sensitive attributes
    Given the provider schema marks an attribute "api_key" as sensitive
    And a ValidateProviderConfig request is made with configuration: `{"api_key": "secret"}`
    When the ValidateProviderConfig RPC is called
    Then the validation should proceed normally based on type and requirement checks
    And the response should not contain errors if the "api_key" is valid
    # Sensitivity is more about how values are handled/displayed, not validation logic itself,
    # but the validation should still occur.

  Scenario: Validate provider configuration where an attribute is marked deprecated
    Given the provider schema marks an attribute "old_setting" as deprecated
    And a ValidateProviderConfig request is made with configuration: `{"old_setting": "value"}`
    When the ValidateProviderConfig RPC is called
    Then the response may contain a warning diagnostic indicating "old_setting" is deprecated
    And the validation of "old_setting" itself (e.g. type check) should still proceed.
    And if "old_setting" is valid apart from being deprecated, no error diagnostic should be present for it.
