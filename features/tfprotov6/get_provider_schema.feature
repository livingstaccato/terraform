# Metadata:
#   Covers: internal/plugin6/grpc_provider_test.go
#   Tests:
#     - TestGRPCProvider_GetProviderSchema
#     - TestGRPCProvider_GetSchema_globalCache
#     - TestGRPCProvider_GetSchema_GRPCError
#     - TestGRPCProvider_GetSchema_ResponseErrorDiagnostic

Feature: GetProviderSchema RPC
  As a Terraform plugin,
  I need to respond to GetProviderSchema requests
  So that Terraform core can understand my capabilities, resource types, and data sources.

  Background:
    Given a configured tfplugin6 gRPC provider server

  Scenario: Successfully retrieve provider schema
    When the GetProviderSchema RPC is called
    Then the response should contain the provider schema
    And the response should contain resource schemas
    And the response should contain data source schemas
    And the response should contain server capabilities
    And the response should not contain errors

  Scenario: Successfully retrieve provider schema from global cache
    Given the provider supports optional GetProviderSchema
    And the provider schema has been previously retrieved and cached
    When the GetProviderSchema RPC is called again for the same provider type
    Then the response should be served from the global cache
    And the response should contain the provider schema
    And the response should contain resource schemas
    And the response should contain data source schemas
    And the response should not contain errors
    # Note: Verification of "served from cache" might require specific mock setup in step definitions
    # or observing that the underlying gRPC client method is not called a second time.

  Scenario: Handle gRPC error during GetProviderSchema
    Given the provider's GetProviderSchema RPC will return a gRPC error
    When the GetProviderSchema RPC is called
    Then the response should contain an error diagnostic reflecting the gRPC error

  Scenario: Handle provider-returned error diagnostic during GetProviderSchema
    Given the provider's GetProviderSchema RPC will return a response with an error diagnostic
    When the GetProviderSchema RPC is called
    Then the response should contain the error diagnostic from the provider

  Scenario: Handle provider-returned warning diagnostic during GetProviderSchema
    Given the provider's GetProviderSchema RPC will return a response with a warning diagnostic
    When the GetProviderSchema RPC is called
    Then the response should contain the warning diagnostic from the provider
    And the response should also contain the provider schema
    And the response should also contain resource schemas
    And the response should also contain data source schemas
    And the response should not contain errors that would halt processing of the schema

  Scenario: Schema definition includes various attribute types
    Given a provider schema with attributes of type string, number, bool, list, map, and object
    When the GetProviderSchema RPC is called
    Then the response should accurately reflect these attribute types in the provider schema
    And the response should accurately reflect these attribute types in resource schemas
    And the response should accurately reflect these attribute types in data source schemas

  Scenario: Schema definition includes required, optional, and computed attributes
    Given a provider schema with attributes marked as required, optional, and computed
    When the GetProviderSchema RPC is called
    Then the response should accurately reflect these attribute properties (required, optional, computed)

  Scenario: Schema definition includes sensitive attributes
    Given a provider schema with attributes marked as sensitive
    When the GetProviderSchema RPC is called
    Then the response should accurately reflect the sensitive nature of these attributes

  Scenario: Schema definition includes deprecated attributes
    Given a provider schema with attributes marked as deprecated
    When the GetProviderSchema RPC is called
    Then the response should accurately reflect the deprecated status of these attributes

  Scenario: Schema definition includes nested blocks
    Given a provider schema with nested blocks (single, list, set, map)
    When the GetProviderSchema RPC is called
    Then the response should accurately reflect the structure and nesting mode of these blocks

  Scenario: Schema definition includes functions
    Given the provider defines custom functions
    When the GetProviderSchema RPC is called
    Then the response should contain the definitions of these functions
    And each function definition should include parameters, return type, and descriptions

  Scenario: Schema definition includes ephemeral resource schemas
    Given the provider defines ephemeral resource types
    When the GetProviderSchema RPC is called
    Then the response should contain the schemas for these ephemeral resources

  Scenario: Schema definition includes list resource schemas
    Given the provider defines list resource types
    When the GetProviderSchema RPC is called
    Then the response should contain the schemas for these list resources

  Scenario: Schema definition includes state store schemas
    Given the provider defines state store types
    When the GetProviderSchema RPC is called
    Then the response should contain the schemas for these state stores

  Scenario: Server capabilities indicate plan_destroy support
    Given the provider supports plan_destroy capability
    When the GetProviderSchema RPC is called
    Then the server_capabilities in the response should indicate plan_destroy is true

  Scenario: Server capabilities indicate move_resource_state support
    Given the provider supports move_resource_state capability
    When the GetProviderSchema RPC is called
    Then the server_capabilities in the response should indicate move_resource_state is true

  Scenario: Provider schema includes provider_meta schema
    Given the provider has a meta schema for its configuration
    When the GetProviderSchema RPC is called
    Then the response should contain the provider_meta schema
    And this schema should define the structure of the provider's configuration block
    And it should include attributes with their types, descriptions, and whether they are required, optional, or computed.
    And the response should not contain errors.

  Scenario: Schema with block versioning
    Given a provider schema where a resource block has a version number
    When the GetProviderSchema RPC is called
    Then the response for that resource schema should include the correct version number for the block
    And the response should not contain errors.

  Scenario: Schema with attribute descriptions and kinds (plain/markdown)
    Given a provider schema with attributes having descriptions
    And some descriptions are plain text and others are markdown
    When the GetProviderSchema RPC is called
    Then the response attributes should include their descriptions
    And the description_kind should correctly indicate PLAIN or MARKDOWN.

  Scenario: Schema with nested block types having min/max items
    Given a provider schema with a nested block type (e.g., LIST or SET)
    And this nested block type has min_items and max_items defined
    When the GetProviderSchema RPC is called
    Then the response for that nested block type should include the min_items and max_items values.
    # Note: While proto defines min/max_items for Object, the comment says they were never used.
    # This scenario focuses on NestedBlock where they are relevant.

  Scenario: Schema with attributes using Object nested_type
    Given a provider schema where an attribute is of an object type defined by Object
    And this Object has its own set of attributes and nesting mode
    When the GetProviderSchema RPC is called
    Then the response for that attribute should correctly represent its nested_type as an Object
    And include the Object's attributes and nesting mode.

  Scenario: Schema with write_only attributes
    Given a provider schema with attributes marked as write_only
    When the GetProviderSchema RPC is called
    Then the response should accurately reflect the write_only status of these attributes.

  Scenario: Function definition with parameters allowing null or unknown values
    Given a provider defines a function with parameters
    And some parameters allow null values
    And some parameters allow unknown values
    When the GetProviderSchema RPC is called
    Then the response function definitions should accurately reflect the allow_null_value and allow_unknown_values flags for each parameter.

  Scenario: Function definition with deprecation message
    Given a provider defines a function that is deprecated
    And the function definition includes a deprecation_message
    When the GetProviderSchema RPC is called
    Then the response for that function should include the deprecation_message.

  Scenario: GetProviderSchema response with no functions defined
    Given a provider that does not define any custom functions
    When the GetProviderSchema RPC is called
    Then the functions map in the response should be empty or null
    And the response should not contain errors related to functions.

  Scenario: GetProviderSchema response with no ephemeral resources defined
    Given a provider that does not define any ephemeral resource types
    When the GetProviderSchema RPC is called
    Then the ephemeral_resource_schemas map in the response should be empty or null
    And the response should not contain errors related to ephemeral resources.

  Scenario: GetProviderSchema response with no list resources defined
    Given a provider that does not define any list resource types
    When the GetProviderSchema RPC is called
    Then the list_resource_schemas map in the response should be empty or null
    And the response should not contain errors related to list resources.

  Scenario: GetProviderSchema response with no state stores defined
    Given a provider that does not define any state store types
    When the GetProviderSchema RPC is called
    Then the state_store_schemas map in the response should be empty or null
    And the response should not contain errors related to state stores.

  Scenario: GetProviderSchema with empty resource and data source schemas
    Given a provider that has a provider schema but no resource or data source types defined
    When the GetProviderSchema RPC is called
    Then the response should contain the provider schema
    And the resource_schemas map should be empty
    And the data_source_schemas map should be empty
    And the response should not contain errors.

  Scenario: GetProviderSchema response when provider schema itself is minimal (e.g. no attributes)
    Given a provider whose provider schema block has no attributes or nested blocks
    When the GetProviderSchema RPC is called
    Then the provider schema in the response should reflect this (e.g., empty attributes list)
    And the response should not contain errors.

  Scenario: Server capabilities indicate no optional features are supported
    Given the provider supports no optional server capabilities (e.g., plan_destroy is false, get_provider_schema_optional is false, move_resource_state is false)
    When the GetProviderSchema RPC is called
    Then the server_capabilities in the response should reflect that these features are false.

  Scenario: Server capabilities are not returned by the provider (nil)
    Given the provider's GetProviderSchema RPC returns a response where server_capabilities is nil
    When the GetProviderSchema RPC is called
    Then the client should handle this gracefully, potentially assuming default capabilities (all false)
    And the response should not contain errors due to missing server capabilities.
    # This tests client-side resilience if a provider sends a malformed/incomplete response.
    # The Go client might instantiate a default ServerCapabilities struct.

  Scenario: GetProviderSchema where provider_meta schema is not defined
    Given the provider does not define a provider_meta schema
    When the GetProviderSchema RPC is called
    Then the provider_meta field in the response should be empty or nil
    And the response should not contain errors.

  Scenario: GetProviderSchema returns a schema with an attribute name containing special characters
    # Assuming attribute names can be flexible, though usually they follow identifier rules.
    # This tests encoding/decoding and handling of such names.
    Given a provider schema has an attribute named "attr-with-hyphen_and.period"
    When the GetProviderSchema RPC is called
    Then the response should correctly include this attribute with its exact name.

  Scenario: GetProviderSchema returns a schema with a block type name containing special characters
    Given a provider schema has a nested block type named "block-type-with-hyphens"
    When the GetProviderSchema RPC is called
    Then the response should correctly include this block type with its exact name.

  Scenario: GetProviderSchema returns a function name containing special characters
    Given a provider defines a function named "func-with-hyphens_and.periods"
    When the GetProviderSchema RPC is called
    Then the response should correctly include this function with its exact name in the functions map.

  Scenario: Schema attribute with an empty description
    Given a provider schema has an attribute with an empty string as its description
    When the GetProviderSchema RPC is called
    Then the response attribute should have an empty description string
    And the description_kind might be PLAIN or as defaulted by the provider.

  Scenario: Schema nested block with an empty description
    Given a provider schema has a nested block with an empty string as its description
    When the GetProviderSchema RPC is called
    Then the response nested block should have an empty description string
    And the description_kind might be PLAIN or as defaulted by the provider.

  Scenario: Function with an empty summary or description
    Given a provider defines a function with an empty summary and/or an empty description
    When the GetProviderSchema RPC is called
    Then the response function definition should reflect these empty strings for summary/description
    And the description_kind might be PLAIN or as defaulted.

  Scenario: Function parameter with an empty description
    Given a provider defines a function with a parameter that has an empty description
    When the GetProviderSchema RPC is called
    Then the response function parameter definition should reflect this empty description string
    And the description_kind might be PLAIN or as defaulted.

  Scenario: Schema version is zero
    Given a provider schema (for provider, resource, or data source) has a version of 0
    When the GetProviderSchema RPC is called
    Then the response should correctly reflect the schema version as 0.

  Scenario: Schema version is a large number
    Given a provider schema (for provider, resource, or data source) has a large version number (e.g., 9999)
    When the GetProviderSchema RPC is called
    Then the response should correctly reflect this large schema version number.

  Scenario: GetProviderSchema when client capabilities are provided in the request
    # Although GetProviderSchema.Request is currently empty, this future-proofs if it ever includes client capabilities
    Given a GetProviderSchema request that includes client capabilities information
    When the GetProviderSchema RPC is called
    Then the provider should process the request successfully
    And the response should contain the schemas and capabilities as expected.
    # This scenario is more about ensuring the provider doesn't break if unexpected fields are present in the request,
    # or if the request object is extended in future protocol versions.
    # The current proto shows GetProviderSchema.Request as empty.

  Scenario: GetProviderSchema response with diagnostic message having an attribute path
    Given the provider's GetProviderSchema RPC will return a response with a diagnostic
    And this diagnostic is associated with a specific attribute path (e.g., "resource.my_resource.attribute_name")
    When the GetProviderSchema RPC is called
    Then the response should contain the diagnostic
    And the diagnostic should include the correct attribute path with its steps.

  Scenario: GetProviderSchema response with diagnostic message not having an attribute path
    Given the provider's GetProviderSchema RPC will return a response with a diagnostic
    And this diagnostic is general and not associated with any specific attribute path
    When the GetProviderSchema RPC is called
    Then the response should contain the diagnostic
    And the diagnostic's attribute path should be empty or nil.

  Scenario: GetProviderSchema response with a schema block that is marked as deprecated
    Given a provider schema where a resource's or data source's main block is marked as deprecated
    When the GetProviderSchema RPC is called
    Then the Block message in the schema response for that resource/data source should have its `deprecated` field set to true.

  Scenario: GetProviderSchema response with a nested block type that is marked as deprecated
    # Note: The proto Schema.Block has `deprecated`, but Schema.NestedBlock does not directly.
    # This implies deprecation is at the Block level itself.
    # If a NestedBlock's *Block* is deprecated, its `deprecated` field should be true.
    Given a provider schema with a nested block type whose underlying Block is marked as deprecated
    When the GetProviderSchema RPC is called
    Then the `block.deprecated` field for that nested block type in the response should be true.

  Scenario: GetProviderSchema for a provider with no resources, data sources, functions, etc. (minimal provider)
    Given a provider that only has a basic provider schema (e.g., configuration attributes)
    And no resource types, data source types, functions, ephemeral resources, list resources, or state stores
    When the GetProviderSchema RPC is called
    Then the response should contain the provider schema
    And all other schema maps (resource_schemas, data_source_schemas, functions, etc.) should be empty or nil
    And the response should not contain errors.

  Scenario: Schema for an attribute of type Object with NestingMode SINGLE
    Given a provider schema has an attribute of type Object
    And its nesting mode is SINGLE
    When the GetProviderSchema RPC is called
    Then the response for this attribute's Object nested_type should have nesting mode SINGLE.

  Scenario: Schema for an attribute of type Object with NestingMode LIST
    Given a provider schema has an attribute of type Object
    And its nesting mode is LIST
    When the GetProviderSchema RPC is called
    Then the response for this attribute's Object nested_type should have nesting mode LIST.

  Scenario: Schema for an attribute of type Object with NestingMode SET
    Given a provider schema has an attribute of type Object
    And its nesting mode is SET
    When the GetProviderSchema RPC is called
    Then the response for this attribute's Object nested_type should have nesting mode SET.

  Scenario: Schema for an attribute of type Object with NestingMode MAP
    Given a provider schema has an attribute of type Object
    And its nesting mode is MAP
    When the GetProviderSchema RPC is called
    Then the response for this attribute's Object nested_type should have nesting mode MAP.

  Scenario: Schema for a NestedBlock with NestingMode GROUP
    Given a provider schema has a nested block type
    And its nesting mode is GROUP
    When the GetProviderSchema RPC is called
    Then the response for this nested block type should have nesting mode GROUP.

  Scenario: Schema defines a function parameter with description kind PLAIN
    Given a provider defines a function with a parameter
    And the parameter's description is plain text
    When the GetProviderSchema RPC is called
    Then the response function parameter definition should have description_kind PLAIN.

  Scenario: Schema defines a function parameter with description kind MARKDOWN
    Given a provider defines a function with a parameter
    And the parameter's description is markdown
    When the GetProviderSchema RPC is called
    Then the response function parameter definition should have description_kind MARKDOWN.

  Scenario: Schema defines a function with summary and description kind PLAIN
    Given a provider defines a function
    And its summary and description are plain text
    When the GetProviderSchema RPC is called
    Then the response function definition should have description_kind PLAIN.

  Scenario: Schema defines a function with summary and description kind MARKDOWN
    Given a provider defines a function
    And its summary and description are markdown
    When the GetProviderSchema RPC is called
    Then the response function definition should have description_kind MARKDOWN.

  Scenario: GetProviderSchema returns diagnostics with varying severity levels
    Given the provider's GetProviderSchema RPC will return multiple diagnostics
    And these diagnostics include ERROR, WARNING, and INVALID severities
    When the GetProviderSchema RPC is called
    Then the response should contain all these diagnostics
    And each diagnostic should have its correct severity level reflected.
    # Note: INVALID severity is defined but its practical use might be limited.
    # The presence of an ERROR diagnostic usually implies failure.
