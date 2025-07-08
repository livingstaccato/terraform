# Metadata:
#   Covers: internal/plugin6/grpc_provider_test.go
#   Tests:
#     - TestGRPCProvider_ValidateDataResourceConfig

Feature: ValidateDataResourceConfig RPC
  As a Terraform plugin,
  I need to respond to ValidateDataResourceConfig requests
  So that Terraform core can validate the configuration for a specific data resource type.

  Background:
    Given a configured tfplugin6 gRPC provider server
    And the provider has a defined schema for a data resource type "my_data_source"

  Scenario: Successfully validate a valid data resource configuration
    Given the "my_data_source" schema defines a required string attribute "query_param"
    And a ValidateDataResourceConfig request is made for "my_data_source" with configuration: `{"query_param": "search_term"}`
    When the ValidateDataResourceConfig RPC is called with this type_name and configuration
    Then the response should not contain any error diagnostics
    And the response should not contain any warning diagnostics

  Scenario: Validate data resource configuration with missing required attribute
    Given the "my_data_source" schema defines a required string attribute "query_param"
    And a ValidateDataResourceConfig request is made for "my_data_source" with an empty configuration: `{}`
    When the ValidateDataResourceConfig RPC is called with this type_name and configuration
    Then the response should contain an error diagnostic indicating "query_param" is required

  Scenario: Validate data resource configuration with attribute of incorrect type
    Given the "my_data_source" schema defines a string attribute "query_param"
    And a ValidateDataResourceConfig request is made for "my_data_source" with configuration: `{"query_param": 123}` (an integer)
    When the ValidateDataResourceConfig RPC is called with this type_name and configuration
    Then the response should contain an error diagnostic indicating "query_param" has an incorrect type

  Scenario: Validate data resource configuration with an unknown attribute
    Given the "my_data_source" schema only defines an attribute "query_param"
    And a ValidateDataResourceConfig request is made for "my_data_source" with configuration: `{"query_param": "value", "unknown_param": "another_value"}`
    When the ValidateDataResourceConfig RPC is called with this type_name and configuration
    Then the response should contain a warning diagnostic indicating "unknown_param" is unexpected
    And the response should not contain error diagnostics for known attributes if they are valid

  Scenario: Validate data resource configuration that is null or empty for a data source with all optional attributes
    Given the "my_data_source" schema defines only optional attributes
    And a ValidateDataResourceConfig request is made for "my_data_source" with a null configuration
    When the ValidateDataResourceConfig RPC is called with this type_name and configuration
    Then the response should not contain any error diagnostics
    And a ValidateDataResourceConfig request is made for "my_data_source" with an empty JSON object configuration `{}`
    When the ValidateDataResourceConfig RPC is called with this type_name and configuration
    Then the response should not contain any error diagnostics

  Scenario: Validate data resource configuration resulting in multiple diagnostics
    Given the "my_data_source" schema defines a required string "req_param" and an optional number "opt_param"
    And a ValidateDataResourceConfig request is made for "my_data_source" with configuration: `{"opt_param": "not_a_number", "unknown_param": "foo"}`
    When the ValidateDataResourceConfig RPC is called with this type_name and configuration
    Then the response should contain an error diagnostic for missing "req_param"
    And the response should contain an error diagnostic for "opt_param" having an incorrect type
    And the response should contain a warning diagnostic for "unknown_param"

  Scenario: Handle gRPC error during ValidateDataResourceConfig
    Given the provider's ValidateDataResourceConfig RPC will return a gRPC error for "my_data_source"
    And a ValidateDataResourceConfig request is made for "my_data_source" with some configuration
    When the ValidateDataResourceConfig RPC is called
    Then the overall operation should result in an error diagnostic reflecting the gRPC error

  Scenario: Validate data resource configuration with complex nested structure
    Given the "my_data_source" schema defines a block attribute "filter" with a required string attribute "field"
    And a ValidateDataResourceConfig request is made for "my_data_source" with configuration: `{"filter": {"field": "name"}}`
    When the ValidateDataResourceConfig RPC is called with this type_name and configuration
    Then the response should not contain any error diagnostics

  Scenario: Validate data resource configuration with missing required attribute in a nested block
    Given the "my_data_source" schema defines a block attribute "filter" with a required string attribute "field"
    And a ValidateDataResourceConfig request is made for "my_data_source" with configuration: `{"filter": {}}`
    When the ValidateDataResourceConfig RPC is called with this type_name and configuration
    Then the response should contain an error diagnostic indicating "filter.field" is required

  Scenario: Diagnostic message includes attribute path for data resource validation error
    Given the "my_data_source" schema defines a string attribute "search_term"
    And a ValidateDataResourceConfig request is made for "my_data_source" with configuration: `{"search_term": 123}`
    When the ValidateDataResourceConfig RPC is called
    Then the response should contain an error diagnostic
    And the diagnostic's attribute path should correctly point to "search_term"

  Scenario: Validate data resource configuration for an unknown data resource type_name
    Given the provider does not define a schema for a data resource type "unknown_data_source"
    And a ValidateDataResourceConfig request is made for "unknown_data_source" with some configuration
    When the ValidateDataResourceConfig RPC is called
    Then the response should contain an error diagnostic indicating "unknown_data_source" is not a valid type

  Scenario: Data resource configuration uses msgpack encoding for DynamicValue
    Given a ValidateDataResourceConfig request is made for "my_data_source" with configuration `{"query_param": "search_term"}` encoded using msgpack
    When the ValidateDataResourceConfig RPC is called with this type_name and msgpack encoded configuration
    Then the provider should correctly decode and validate the configuration
    And the response should not contain any error diagnostics

  Scenario: Data resource configuration uses JSON encoding for DynamicValue
    Given a ValidateDataResourceConfig request is made for "my_data_source" with configuration `{"query_param": "search_term"}` encoded using JSON
    When the ValidateDataResourceConfig RPC is called with this type_name and JSON encoded configuration
    Then the provider should correctly decode and validate the configuration
    And the response should not contain any error diagnostics

  Scenario: Validate data resource configuration with deprecated attributes
    Given the "my_data_source" schema marks an attribute "old_filter" as deprecated
    And a ValidateDataResourceConfig request is made for "my_data_source" with configuration `{"old_filter": "some_criteria"}`
    When the ValidateDataResourceConfig RPC is called
    Then the response may contain a warning diagnostic for "old_filter"
    And if "old_filter" is valid by its schema (type, etc.), no error diagnostic should be present for it.

  Scenario: Validate data resource configuration where the data source block itself is deprecated
    Given the schema for "my_data_source" itself (the top-level block) is marked as deprecated
    And a ValidateDataResourceConfig request is made for "my_data_source" with valid configuration `{"query_param": "value"}`
    When the ValidateDataResourceConfig RPC is called
    Then the response may contain a warning diagnostic indicating that the data source type "my_data_source" is deprecated
    And validation of the configuration itself should still proceed.
    And if the configuration is valid, no error diagnostics should be present.
    # Note: ValidateDataResourceConfig.Request does not include ClientCapabilities, unlike ValidateResourceConfig.
    # So no scenario for that is needed here.
