# Metadata:
#   Covers: internal/plugin6/grpc_provider_test.go
#   Tests:
#     - TestGRPCProvider_ValidateListResourceConfig
#     - TestGRPCProvider_ValidateListResourceConfig_OptionalCfg

Feature: ValidateListResourceConfig RPC
  As a Terraform plugin,
  I need to respond to ValidateListResourceConfig requests
  So that Terraform core can validate the configuration for a specific list resource type.

  Background:
    Given a configured tfplugin6 gRPC provider server
    And the provider has a defined schema for a list resource type "my_list_resource"
    And this schema includes a "config" block with a required string attribute "filter_attr"
    And this schema defines how "include_resource_object" (boolean) and "limit" (number) are handled

  Scenario: Successfully validate a valid list resource configuration
    Given a ValidateListResourceConfig request for "my_list_resource" with:
      | config                  | {"filter_attr": "value"} |
      | include_resource_object | true                     |
      | limit                   | 100                      |
    When the ValidateListResourceConfig RPC is called with this type_name and configuration values
    Then the response should not contain any error diagnostics
    And the response should not contain any warning diagnostics

  Scenario: Validate list resource configuration with missing required attribute in config block
    Given a ValidateListResourceConfig request for "my_list_resource" with:
      | config                  | {}                       | # Missing filter_attr
      | include_resource_object | false                    |
      | limit                   | 50                       |
    When the ValidateListResourceConfig RPC is called
    Then the response should contain an error diagnostic indicating "config.filter_attr" is required

  Scenario: Validate list resource configuration with attribute of incorrect type in config block
    Given a ValidateListResourceConfig request for "my_list_resource" with:
      | config                  | {"filter_attr": 123}     | # Incorrect type
      | include_resource_object | true                     |
      | limit                   | 20                       |
    When the ValidateListResourceConfig RPC is called
    Then the response should contain an error diagnostic indicating "config.filter_attr" has an incorrect type

  Scenario: Validate list resource configuration with an unknown attribute in config block
    Given a ValidateListResourceConfig request for "my_list_resource" with:
      | config                  | {"filter_attr": "value", "unknown_attr": "foo"} |
      | include_resource_object | false                                           |
      | limit                   | 10                                              |
    When the ValidateListResourceConfig RPC is called
    Then the response should contain a warning diagnostic indicating "config.unknown_attr" is unexpected

  Scenario: Validate list resource with optional config attributes (e.g. filter_attr is optional)
    Given the "my_list_resource" schema's "config" block has "filter_attr" as optional
    And a ValidateListResourceConfig request for "my_list_resource" with:
      | config                  | {}    | # filter_attr is now optional and omitted
      | include_resource_object | true  |
      | limit                   | 30    |
    When the ValidateListResourceConfig RPC is called
    Then the response should not contain any error diagnostics related to "config.filter_attr"

  Scenario: Validate list resource configuration with invalid type for include_resource_object
    Given a ValidateListResourceConfig request for "my_list_resource" with:
      | config                  | {"filter_attr": "value"} |
      | include_resource_object | "not_a_boolean"          | # Incorrect type
      | limit                   | 10                       |
    When the ValidateListResourceConfig RPC is called
    Then the response should contain an error diagnostic indicating "include_resource_object" has an incorrect type

  Scenario: Validate list resource configuration with invalid type for limit
    Given a ValidateListResourceConfig request for "my_list_resource" with:
      | config                  | {"filter_attr": "value"} |
      | include_resource_object | true                     |
      | limit                   | "not_a_number"           | # Incorrect type
    When the ValidateListResourceConfig RPC is called
    Then the response should contain an error diagnostic indicating "limit" has an incorrect type

  Scenario: Validate list resource configuration with null or omitted optional fields (include_resource_object, limit)
    # Assuming include_resource_object and limit are optional or have defaults if not provided
    Given a ValidateListResourceConfig request for "my_list_resource" with:
      | config                  | {"filter_attr": "value"} |
      # include_resource_object is omitted
      # limit is omitted
    When the ValidateListResourceConfig RPC is called
    Then the response should not contain any error diagnostics related to missing include_resource_object or limit
    And a ValidateListResourceConfig request for "my_list_resource" with:
      | config                  | {"filter_attr": "value"} |
      | include_resource_object | null                     |
      | limit                   | null                     |
    When the ValidateListResourceConfig RPC is called
    Then the response should not contain any error diagnostics related to null include_resource_object or limit

  Scenario: Validate list resource configuration resulting in multiple diagnostics
    Given a ValidateListResourceConfig request for "my_list_resource" with:
      | config                  | {"unknown_attr": "foo"}  | # Missing filter_attr, has unknown
      | include_resource_object | "invalid"                | # Wrong type
      | limit                   | -5                       | # Potentially invalid value for limit
    When the ValidateListResourceConfig RPC is called
    Then the response should contain an error diagnostic for missing "config.filter_attr"
    And the response should contain a warning diagnostic for "config.unknown_attr"
    And the response should contain an error diagnostic for "include_resource_object" having an incorrect type
    And the response may contain an error diagnostic for "limit" having an invalid value (e.g. negative)

  Scenario: Handle gRPC error during ValidateListResourceConfig
    Given the provider's ValidateListResourceConfig RPC will return a gRPC error for "my_list_resource"
    And a ValidateListResourceConfig request is made for "my_list_resource"
    When the ValidateListResourceConfig RPC is called
    Then the overall operation should result in an error diagnostic reflecting the gRPC error

  Scenario: Diagnostic message includes attribute path for list resource validation error
    Given a ValidateListResourceConfig request for "my_list_resource" with:
      | config                  | {"filter_attr": 123}     |
      | include_resource_object | true                     |
      | limit                   | 10                       |
    When the ValidateListResourceConfig RPC is called
    Then the response should contain an error diagnostic
    And the diagnostic's attribute path should correctly point to "config.filter_attr"

  Scenario: Validate list resource configuration for an unknown list resource type_name
    Given the provider does not define a schema for a list resource type "unknown_list_resource"
    And a ValidateListResourceConfig request is made for "unknown_list_resource"
    When the ValidateListResourceConfig RPC is called
    Then the response should contain an error diagnostic indicating "unknown_list_resource" is not a valid type

  Scenario: ValidateListResourceConfig with all inputs as DynamicValue msgpack encoded
    Given the "my_list_resource" schema's "config" block has "filter_attr" as optional string
    And a ValidateListResourceConfig request for "my_list_resource" with all inputs encoded as msgpack:
      | config (msgpack)                  | (msgpack for `{"filter_attr": "value"}`) |
      | include_resource_object (msgpack) | (msgpack for `true`)                     |
      | limit (msgpack)                   | (msgpack for `100`)                      |
    When the ValidateListResourceConfig RPC is called
    Then the provider should correctly decode and validate all parts of the configuration
    And the response should not contain any error diagnostics

  Scenario: ValidateListResourceConfig with all inputs as DynamicValue JSON encoded
    Given the "my_list_resource" schema's "config" block has "filter_attr" as optional string
    And a ValidateListResourceConfig request for "my_list_resource" with all inputs encoded as JSON:
      | config (json)                  | `{"filter_attr": "value"}` |
      | include_resource_object (json) | `true`                     |
      | limit (json)                   | `100`                      |
    When the ValidateListResourceConfig RPC is called
    Then the provider should correctly decode and validate all parts of the configuration
    And the response should not contain any error diagnostics

  Scenario: Validate list resource configuration where the list resource block itself is deprecated
    Given the schema for "my_list_resource" itself (the top-level block) is marked as deprecated
    And a ValidateListResourceConfig request is made for "my_list_resource" with valid configuration
    When the ValidateListResourceConfig RPC is called
    Then the response may contain a warning diagnostic indicating that the list resource type "my_list_resource" is deprecated
    And validation of the configuration itself should still proceed.
    And if the configuration is valid, no error diagnostics should be present.

  Scenario: Validate list resource configuration where an attribute within the config block is deprecated
    Given the "my_list_resource" schema's "config" block has an attribute "old_filter" marked as deprecated
    And a ValidateListResourceConfig request for "my_list_resource" with:
      | config                  | {"filter_attr": "value", "old_filter": "criteria"} |
      | include_resource_object | true                                               |
      | limit                   | 10                                                 |
    When the ValidateListResourceConfig RPC is called
    Then the response may contain a warning diagnostic for "config.old_filter"
    And if "config.old_filter" is valid by its schema, no error diagnostic should be present for it.

  Scenario: Validate list resource configuration with empty config block when it's allowed
    Given the "my_list_resource" schema's "config" block is optional or has no required attributes
    And a ValidateListResourceConfig request for "my_list_resource" with:
      | config                  | {}    |
      | include_resource_object | true  |
      | limit                   | 10    |
    When the ValidateListResourceConfig RPC is called
    Then the response should not contain any error diagnostics regarding the empty config block.

  Scenario: Validate list resource configuration with null config block when it's allowed
    Given the "my_list_resource" schema's "config" block is optional or has no required attributes
    And a ValidateListResourceConfig request for "my_list_resource" with:
      | config                  | null  |
      | include_resource_object | true  |
      | limit                   | 10    |
    When the ValidateListResourceConfig RPC is called
    Then the response should not contain any error diagnostics regarding the null config block.
