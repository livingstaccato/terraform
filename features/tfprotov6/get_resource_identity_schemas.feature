# Metadata:
#   Covers: internal/plugin6/grpc_provider_test.go
#   Tests:
#     - TestGRPCProvider_GetResourceIdentitySchemas
#     - TestGRPCProvider_GetResourceIdentitySchemas_Unimplemented
#     - TestGRPCProvider_GetSchema_IdentityError (related parts)
#     - TestGRPCProvider_GetSchema_IdentityUnimplemented (related parts)
#     - TestGRPCProvider_GetSchema_IdentityErrorDiagnostic (related parts)

Feature: GetResourceIdentitySchemas RPC
  As a Terraform plugin,
  I need to respond to GetResourceIdentitySchemas requests
  So that Terraform core can understand how to uniquely identify instances of my managed resource types.

  Background:
    Given a configured tfplugin6 gRPC provider server

  Scenario: Successfully retrieve resource identity schemas
    Given the provider defines resource identity schemas for its managed resources
    When the GetResourceIdentitySchemas RPC is called
    Then the response should contain a map of resource type names to their identity schemas
    And each identity schema should include a version and identity attributes
    And each identity attribute should define its name, type, import requirements, and description
    And the response should not contain errors

  Scenario: Provider has no managed resources with identity schemas
    Given the provider defines no specific resource identity schemas (or has no managed resources)
    When the GetResourceIdentitySchemas RPC is called
    Then the identity_schemas map in the response should be empty
    And the response should not contain errors

  Scenario: Handle gRPC error during GetResourceIdentitySchemas
    Given the provider's GetResourceIdentitySchemas RPC will return a gRPC error (e.g., server unavailable)
    When the GetResourceIdentitySchemas RPC is called
    Then the response should contain an error diagnostic reflecting the gRPC error

  Scenario: Handle provider-returned error diagnostic during GetResourceIdentitySchemas
    Given the provider's GetResourceIdentitySchemas RPC will return a response with an error diagnostic
    When the GetResourceIdentitySchemas RPC is called
    Then the response should contain the error diagnostic from the provider
    And the identity_schemas map may be empty or partially filled depending on the error

  Scenario: Handle provider-returned warning diagnostic during GetResourceIdentitySchemas
    Given the provider's GetResourceIdentitySchemas RPC will return a response with a warning diagnostic
    And the provider also returns valid identity schemas
    When the GetResourceIdentitySchemas RPC is called
    Then the response should contain the warning diagnostic from the provider
    And the response should also contain the valid map of resource identity schemas
    And the response should not contain errors that would halt processing of the schemas

  Scenario: GetResourceIdentitySchemas RPC is unimplemented by the provider
    Given the provider does not implement the GetResourceIdentitySchemas RPC (returns Unimplemented gRPC status)
    When the GetResourceIdentitySchemas RPC is called
    Then the client should handle this gracefully (e.g., by assuming no identity schemas or default behavior)
    And the response should not contain errors that would prevent Terraform from proceeding
    # Note: The Go client in grpc_provider_test.go treats Unimplemented as non-fatal for GetResourceIdentitySchemas.

  Scenario: Resource identity schema with various attribute types
    Given a resource identity schema defines attributes with types string, number, and bool
    # Identity attributes are typically simple scalar types.
    When the GetResourceIdentitySchemas RPC is called
    Then the response should accurately reflect these attribute types in the identity_attributes.

  Scenario: Resource identity schema attribute properties
    Given a resource identity schema defines an attribute
    And the attribute has a name, type, description, version
    And the attribute is marked as required_for_import = true
    And another attribute is marked as optional_for_import = true
    When the GetResourceIdentitySchemas RPC is called
    Then the response for that identity schema should accurately reflect these properties for each attribute.

  Scenario: Resource identity schema with a specific version
    Given a resource identity schema for "my_resource" has version 3
    When the GetResourceIdentitySchemas RPC is called
    Then the identity_schema for "my_resource" in the response should have version 3.

  Scenario: Multiple resource types with different identity schemas
    Given a provider manages "resource_a" and "resource_b"
    And "resource_a" has identity schema version 1 with attributes "id", "location"
    And "resource_b" has identity schema version 2 with attributes "uuid", "name", "region"
    When the GetResourceIdentitySchemas RPC is called
    Then the response should contain the identity schema for "resource_a" as defined
    And the response should contain the identity schema for "resource_b" as defined.

  Scenario: Resource identity attribute with plain text description
    Given a resource identity schema defines an attribute with a plain text description
    When the GetResourceIdentitySchemas RPC is called
    Then the response attribute's description should be the plain text
    # The proto does not specify StringKind for IdentityAttribute descriptions, implies PLAIN.

  Scenario: Resource identity attribute with an empty description
    Given a resource identity schema defines an attribute with an empty description string
    When the GetResourceIdentitySchemas RPC is called
    Then the response attribute's description should be an empty string.

  Scenario: Resource identity schema with no attributes
    Given a resource identity schema for "my_resource" has version 1 but defines no identity_attributes
    When the GetResourceIdentitySchemas RPC is called
    Then the identity_schema for "my_resource" in the response should have an empty list of identity_attributes
    And the response should not contain errors.

  Scenario: Diagnostic message in GetResourceIdentitySchemas response with an attribute path
    # Although identity schemas are simpler, a diagnostic might still point to a path if relevant (e.g. within the request if it had parameters)
    # Or more likely, a general diagnostic about a specific resource type's identity schema.
    Given the provider's GetResourceIdentitySchemas RPC will return a response with a diagnostic
    And this diagnostic is associated with a specific resource type (e.g., "Error processing identity for my_resource")
    When the GetResourceIdentitySchemas RPC is called
    Then the response should contain the diagnostic
    And if the diagnostic has an attribute path, it should be correctly represented.
    # For GetResourceIdentitySchemas, AttributePath in diagnostics might be less common than general diagnostics.

  Scenario: Comparing identity_attributes data with differing versions
    # This is more of a conceptual test related to the *use* of identity schemas,
    # but the schema definition itself supports versioning which implies this behavior.
    Given a resource "my_resource" has identity data based on identity_schema version 1
    And a new identity_schema version 2 is defined for "my_resource"
    When comparing identity data, if versions differ (1 vs 2)
    Then they should always be treated as unequal, regardless of attribute values.
    # This scenario highlights the importance of the 'version' field in ResourceIdentitySchema.
    # The RPC itself just returns the schema; comparison logic is in core/consumer.
    # BDD step would focus on "Then the schema indicates version X for resource Y"

  Scenario: Resource identity attribute type is an encoded cty.Type JSON byte slice
    Given a resource identity schema defines an attribute "my_attr"
    And its type is specified as the JSON byte representation of cty.String
    When the GetResourceIdentitySchemas RPC is called
    Then the response for "my_attr" should contain these exact JSON bytes for its type.

  Scenario: Identity schema with an attribute name containing special characters
    Given a resource identity schema has an attribute named "id-with-hyphen.and_period"
    When the GetResourceIdentitySchemas RPC is called
    Then the response should correctly include this identity attribute with its exact name.

  Scenario: Identity schema for a resource type name containing special characters
    Given a provider defines an identity schema for a resource type named "my-resource/type_with_special_chars"
    When the GetResourceIdentitySchemas RPC is called
    Then the identity_schemas map key in the response should be "my-resource/type_with_special_chars"
    And it should map to the correct identity schema.
