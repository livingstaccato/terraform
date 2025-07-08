# Metadata:
#   Covers: internal/plugin6/grpc_provider_test.go
#   Tests:
#     - TestGRPCProvider_ImportResourceState
#     - TestGRPCProvider_ImportResourceStateJSON
#     - TestGRPCProvider_ImportResourceState_Identity

Feature: ImportResourceState RPC
  As a Terraform plugin,
  I need to respond to ImportResourceState requests
  So that Terraform core can bring existing infrastructure under my management.

  Background:
    Given a configured tfplugin6 gRPC provider server
    And the provider defines a managed resource type "my_importable_resource"
    And its schema includes attributes "id" (string, computed), "name" (string), "region" (string, computed)
    And its resource identity schema (version 1) uses "import_id" (string, required_for_import) and "location" (string, optional_for_import)

  Scenario: Successfully import a resource using its ID
    Given an existing remote resource of type "my_importable_resource" can be identified by ID "remote-res-123"
    And importing it yields state `{"id": "remote-res-123", "name": "imported_resource_1", "region": "us-east-1"}`
    And the provider will return the imported state and identity encoded in msgpack
    When an ImportResourceState request is made for "my_importable_resource" with ID "remote-res-123"
    Then the response should contain one imported_resource
    And that resource's type_name should be "my_importable_resource"
    And its state (DynamicValue, msgpack) should reflect `{"id": "remote-res-123", "name": "imported_resource_1", "region": "us-east-1"}`
    And its identity (DynamicValue, msgpack) should reflect the resource's identity (e.g. `{"import_id": "remote-res-123"}`)
    And the response should not contain any error diagnostics

  Scenario: Successfully import a resource using its ID (JSON encoding)
    Given an existing remote resource of type "my_importable_resource" can be identified by ID "remote-res-456"
    And importing it yields state `{"id": "remote-res-456", "name": "imported_resource_2", "region": "eu-west-2"}`
    And the provider will return the imported state and identity encoded in JSON
    When an ImportResourceState request is made for "my_importable_resource" with ID "remote-res-456"
    Then the response should contain one imported_resource
    And its state (DynamicValue, JSON) should reflect `{"id": "remote-res-456", "name": "imported_resource_2", "region": "eu-west-2"}`
    And its identity (DynamicValue, JSON) should reflect the resource's identity (e.g. `{"import_id": "remote-res-456"}`)
    And the response should not contain any error diagnostics

  Scenario: Import a resource that cannot be found by the given ID
    Given no remote resource of type "my_importable_resource" matches ID "non-existent-id"
    When an ImportResourceState request is made for "my_importable_resource" with ID "non-existent-id"
    Then the response should contain an error diagnostic indicating the resource was not found
    And the imported_resources list in the response should be empty

  Scenario: Import operation is deferred by the provider
    Given an ImportResourceState request is made for "my_importable_resource" with ID "defer-import-id"
    And the provider needs to defer the import (e.g., provider config unknown)
    And the provider will return a deferred response with reason PROVIDER_CONFIG_UNKNOWN
    When the ImportResourceState RPC is called
    Then the response should indicate the operation is deferred
    And the deferred reason should be PROVIDER_CONFIG_UNKNOWN
    And the imported_resources list might be empty
    And the response should not contain error diagnostics unless deferral itself is an error

  Scenario: Import resource encounters an API error (e.g., permission denied)
    Given an ImportResourceState request is made for "my_importable_resource" with ID "error-import-id"
    And the provider encounters an API error (e.g., permission denied) while trying to read the remote resource
    When the ImportResourceState RPC is called
    Then the response should contain an error diagnostic explaining the API failure
    And the imported_resources list should be empty

  Scenario: Handle gRPC error during ImportResourceState
    Given the provider's ImportResourceState RPC will return a gRPC error
    When an ImportResourceState request is made
    Then the overall operation should result in an error diagnostic reflecting the gRPC error

  Scenario: Import resource for an unknown resource type_name
    Given an ImportResourceState request is made for an unknown type "unknown_import_resource" with some ID
    When the ImportResourceState RPC is called
    Then the response should contain an error diagnostic indicating "unknown_import_resource" is not a valid type

  Scenario: ImportResourceState request includes client capabilities
    Given an ImportResourceState request for "my_importable_resource" with ID "cap-import-id"
    And the request includes client capabilities (e.g. `deferral_allowed = true`)
    When the ImportResourceState RPC is called
    Then the provider should acknowledge these client capabilities
    And if deferral is needed and allowed, a deferred response is permissible.
    And the import should otherwise proceed normally.

  Scenario: ImportResourceState returns private (meta) data with the imported resource
    Given importing "my_importable_resource" with ID "meta-import-id" also yields some private metadata `{"internal_ref": "ref-xyz"}`
    When an ImportResourceState request is made
    Then the response's imported_resource should include the private byte slice `{"internal_ref": "ref-xyz"}`.

  Scenario: ImportResourceState using resource identity data (instead of simple ID string)
    Given an existing remote resource of type "my_importable_resource"
    And it can be identified by identity data `{"import_id": "identity-based-id", "location": "us-west-1"}` (matching identity schema v1)
    And importing it yields state `{"id": "identity-based-id", "name": "imported_by_identity", "region": "us-west-1"}`
    When an ImportResourceState request is made for "my_importable_resource" with this identity data (no simple ID string)
    Then the response should contain one imported_resource
    And its state should reflect `{"id": "identity-based-id", "name": "imported_by_identity", "region": "us-west-1"}`
    And its identity should match or be refined from the input identity data.

  Scenario: ImportResourceState request provides both ID string and identity data
    # The proto implies one or the other, but if both are sent, provider needs defined behavior.
    # Typically, structured identity data would take precedence if available and supported.
    Given an ImportResourceState request for "my_importable_resource" provides ID "some-id"
    And also provides identity data `{"import_id": "authoritative-id"}`
    And the resource is found using "authoritative-id"
    When the ImportResourceState RPC is called
    Then the provider should use the identity data for import if available and schema-compliant
    And the import should succeed based on "authoritative-id".

  Scenario: Import results in multiple resources (e.g., importing a primary resource and its sub-components)
    # Some providers might import related resources.
    Given importing "my_importable_resource" with ID "parent-res" also discovers a related "sub_resource_type" with ID "child-res"
    And state for "parent-res" is `{"id": "parent-res", ...}`
    And state for "sub_resource_type" is `{"id": "child-res", ...}`
    When an ImportResourceState request is made for "my_importable_resource" with ID "parent-res"
    Then the response's imported_resources list should contain two items:
      | type_name               | state                              |
      | my_importable_resource  | `{"id": "parent-res", ...}`        |
      | sub_resource_type       | `{"id": "child-res", ...}`         |
    And each should have its respective type_name, state, private data, and identity.

  Scenario: Imported resource's state contains sensitive attributes
    Given "my_importable_resource" schema includes a sensitive attribute "api_key"
    And importing resource ID "sensitive-res-id" yields state `{"id": "sensitive-res-id", "api_key": "secret_value_from_remote"}`
    When an ImportResourceState request is made
    Then the imported_resource's state should contain `{"api_key": "secret_value_from_remote"}`
    And Terraform Core is responsible for handling this sensitive value appropriately.

  Scenario: ID string for import contains special characters
    Given an existing remote resource is identified by ID "res/with/slashes-and-%chars"
    And importing it is successful
    When an ImportResourceState request is made with ID "res/with/slashes-and-%chars"
    Then the import should succeed based on this ID.

  Scenario: Resource identity data for import contains attributes with special characters in names or values
    Given an existing remote resource is identified by identity data `{"import-id_with-hyphen": "value/with/slash"}`
    And importing it is successful
    When an ImportResourceState request is made with this identity data
    Then the import should succeed.

  Scenario: Import a resource that requires specific identity attributes not provided
    Given the resource identity schema for "my_importable_resource" has "import_id" (required_for_import) and "zone" (required_for_import)
    And an ImportResourceState request is made using identity data `{"import_id": "some-id"}` (missing "zone")
    When the ImportResourceState RPC is called
    Then the response should contain an error diagnostic indicating that "zone" is required for import.

  Scenario: Import a resource using optional identity attributes
    Given the resource identity schema for "my_importable_resource" has "import_id" (required_for_import) and "location" (optional_for_import)
    And an existing resource can be uniquely identified by `{"import_id": "id-only"}` even without "location"
    And importing it yields a valid state
    When an ImportResourceState request is made using identity data `{"import_id": "id-only"}`
    Then the import should succeed
    And the response should not contain errors related to the omitted "location".

  Scenario: Import a resource where the provider populates optional identity attributes
    Given the resource identity schema has "import_id" (required) and "location" (optional_for_import)
    And an ImportResourceState request is made with `{"import_id": "id-for-optional-fill"}`
    And the provider, upon finding the resource, determines its location is "eu-central-1"
    When the ImportResourceState RPC is called
    Then the imported_resource in the response should have identity data like `{"import_id": "id-for-optional-fill", "location": "eu-central-1"}`.
    # This shows the provider can enrich the identity data.
