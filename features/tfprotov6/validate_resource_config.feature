# Metadata:
#   Covers: internal/plugin6/grpc_provider_test.go
#   Tests:
#     - TestGRPCProvider_ValidateResourceConfig

Feature: ValidateResourceConfig RPC
  As a Terraform plugin,
  I need to respond to ValidateResourceConfig requests
  So that Terraform core can validate the configuration for a specific managed resource type.

  Background:
    Given a configured tfplugin6 gRPC provider server
    And the provider has a defined schema for a managed resource type "my_resource"

  Scenario: Successfully validate a valid resource configuration
    Given the "my_resource" schema defines a required string attribute "res_attr"
    And a ValidateResourceConfig request is made for "my_resource" with configuration: `{"res_attr": "valid_value"}`
    When the ValidateResourceConfig RPC is called with this type_name and configuration
    Then the response should not contain any error diagnostics
    And the response should not contain any warning diagnostics

  Scenario: Validate resource configuration with missing required attribute
    Given the "my_resource" schema defines a required string attribute "res_attr"
    And a ValidateResourceConfig request is made for "my_resource" with an empty configuration: `{}`
    When the ValidateResourceConfig RPC is called with this type_name and configuration
    Then the response should contain an error diagnostic indicating "res_attr" is required

  Scenario: Validate resource configuration with attribute of incorrect type
    Given the "my_resource" schema defines a string attribute "res_attr"
    And a ValidateResourceConfig request is made for "my_resource" with configuration: `{"res_attr": 123}` (an integer)
    When the ValidateResourceConfig RPC is called with this type_name and configuration
    Then the response should contain an error diagnostic indicating "res_attr" has an incorrect type

  Scenario: Validate resource configuration with an unknown attribute
    Given the "my_resource" schema only defines an attribute "res_attr"
    And a ValidateResourceConfig request is made for "my_resource" with configuration: `{"res_attr": "value", "unknown_res_attr": "another_value"}`
    When the ValidateResourceConfig RPC is called with this type_name and configuration
    Then the response should contain a warning diagnostic indicating "unknown_res_attr" is unexpected
    And the response should not contain error diagnostics for known attributes if they are valid

  Scenario: Validate resource configuration that is null or empty for a resource with all optional attributes
    Given the "my_resource" schema defines only optional attributes
    And a ValidateResourceConfig request is made for "my_resource" with a null configuration
    When the ValidateResourceConfig RPC is called with this type_name and configuration
    Then the response should not contain any error diagnostics
    And a ValidateResourceConfig request is made for "my_resource" with an empty JSON object configuration `{}`
    When the ValidateResourceConfig RPC is called with this type_name and configuration
    Then the response should not contain any error diagnostics

  Scenario: Validate resource configuration resulting in multiple diagnostics
    Given the "my_resource" schema defines a required string "req_res_attr" and an optional number "opt_res_attr"
    And a ValidateResourceConfig request is made for "my_resource" with configuration: `{"opt_res_attr": "not_a_number", "unknown_res_attr": "foo"}`
    When the ValidateResourceConfig RPC is called with this type_name and configuration
    Then the response should contain an error diagnostic for missing "req_res_attr"
    And the response should contain an error diagnostic for "opt_res_attr" having an incorrect type
    And the response should contain a warning diagnostic for "unknown_res_attr"

  Scenario: Handle gRPC error during ValidateResourceConfig
    Given the provider's ValidateResourceConfig RPC will return a gRPC error for "my_resource"
    And a ValidateResourceConfig request is made for "my_resource" with some configuration
    When the ValidateResourceConfig RPC is called
    Then the overall operation should result in an error diagnostic reflecting the gRPC error

  Scenario: Validate resource configuration with complex nested structure
    Given the "my_resource" schema defines a block attribute "settings" with a required string attribute "url"
    And a ValidateResourceConfig request is made for "my_resource" with configuration: `{"settings": {"url": "http://example.com"}}`
    When the ValidateResourceConfig RPC is called with this type_name and configuration
    Then the response should not contain any error diagnostics

  Scenario: Validate resource configuration with missing required attribute in a nested block
    Given the "my_resource" schema defines a block attribute "settings" with a required string attribute "url"
    And a ValidateResourceConfig request is made for "my_resource" with configuration: `{"settings": {}}`
    When the ValidateResourceConfig RPC is called with this type_name and configuration
    Then the response should contain an error diagnostic indicating "settings.url" is required

  Scenario: Diagnostic message includes attribute path for resource validation error
    Given the "my_resource" schema defines a string attribute "config_value"
    And a ValidateResourceConfig request is made for "my_resource" with configuration: `{"config_value": 123}`
    When the ValidateResourceConfig RPC is called
    Then the response should contain an error diagnostic
    And the diagnostic's attribute path should correctly point to "config_value" (or "my_resource.config_value" depending on path construction conventions)

  Scenario: Validate resource configuration for an unknown resource type_name
    Given the provider does not define a schema for a resource type "unknown_resource"
    And a ValidateResourceConfig request is made for "unknown_resource" with some configuration
    When the ValidateResourceConfig RPC is called
    Then the response should contain an error diagnostic indicating "unknown_resource" is not a valid type
    # Or the gRPC call itself might fail if the client checks type_name validity first.
    # Assuming the call reaches the provider and provider is responsible for this validation.

  Scenario: Resource configuration uses msgpack encoding for DynamicValue
    Given a ValidateResourceConfig request is made for "my_resource" with configuration `{"res_attr": "valid_value"}` encoded using msgpack
    When the ValidateResourceConfig RPC is called with this type_name and msgpack encoded configuration
    Then the provider should correctly decode and validate the configuration
    And the response should not contain any error diagnostics

  Scenario: Resource configuration uses JSON encoding for DynamicValue
    Given a ValidateResourceConfig request is made for "my_resource" with configuration `{"res_attr": "valid_value"}` encoded using JSON
    When the ValidateResourceConfig RPC is called with this type_name and JSON encoded configuration
    Then the provider should correctly decode and validate the configuration
    And the response should not contain any error diagnostics

  Scenario: Validate resource configuration when client capabilities are provided
    Given a ValidateResourceConfig request for "my_resource" includes client capabilities (e.g., `deferral_allowed = true`)
    And the configuration is `{"res_attr": "valid_value"}`
    When the ValidateResourceConfig RPC is called with these details
    Then the provider should acknowledge the client capabilities if relevant to validation
    And the response should not contain errors if the configuration is valid.
    # This tests if the provider handles the client_capabilities field correctly.

  Scenario: Validate resource configuration with write_only attributes
    Given the "my_resource" schema defines a write_only string attribute "init_param"
    And a ValidateResourceConfig request is made for "my_resource" with configuration `{"init_param": "initial_value"}`
    When the ValidateResourceConfig RPC is called
    Then validation for "init_param" (e.g., type, required) should proceed normally
    And the response should not contain errors if "init_param" is valid.
    # write_only affects plan/apply/read, but config validation should still occur.

  Scenario: Validate resource configuration with deprecated attributes
    Given the "my_resource" schema marks an attribute "old_config" as deprecated
    And a ValidateResourceConfig request is made for "my_resource" with configuration `{"old_config": "some_value"}`
    When the ValidateResourceConfig RPC is called
    Then the response may contain a warning diagnostic for "old_config"
    And if "old_config" is valid by its schema (type, etc.), no error diagnostic should be present for it.

  Scenario: Validate resource configuration where the resource block itself is deprecated
    Given the schema for "my_resource" itself (the top-level block) is marked as deprecated
    And a ValidateResourceConfig request is made for "my_resource" with valid configuration `{"res_attr": "value"}`
    When the ValidateResourceConfig RPC is called
    Then the response may contain a warning diagnostic indicating that the resource type "my_resource" is deprecated
    And validation of the configuration itself should still proceed.
    And if the configuration is valid, no error diagnostics should be present.
