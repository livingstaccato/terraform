# Metadata:
#   Covers: internal/plugin6/grpc_provider_test.go
#   Tests:
#     - TestGRPCProvider_MoveResourceState
#     - TestGRPCProvider_MoveResourceStateJSON

Feature: MoveResourceState RPC
  As a Terraform plugin,
  I need to respond to MoveResourceState requests
  So that Terraform core can facilitate resource refactoring by moving state between different resource types or providers,
  allowing me to transform the incoming state and identity to match the target resource type's schema.

  Background:
    Given a configured tfplugin6 gRPC provider server (acting as the target provider)
    And this provider defines a target managed resource type "my_target_resource"
    And its schema (version 1) includes attributes "target_attr" (string), "shared_id" (string)
    And its identity schema (version 1) includes "target_identity_attr" (string)

  Scenario: Successfully move and transform resource state to a compatible target type (msgpack response)
    Given a source resource state (JSON) `{"source_attr": "value_to_transform", "common_id": "id-123"}` from "source_type" (schema version 1)
    And source private data `{"source_meta": "info"}`
    And source identity data (JSON) `{"source_identity_attr": "identity_val"}` (identity schema version 1)
    And the target provider "my_target_resource" can transform this into state `{"target_attr": "transformed_value_to_transform", "shared_id": "id-123"}`
    And new target private data `{"target_meta": "new_info"}`
    And new target identity data `{"target_identity_attr": "transformed_identity_val"}`
    And the provider will return the target state, private data, and identity encoded in msgpack
    When a MoveResourceState request is made:
      | source_provider_address        | "registry.terraform.io/source/provider" |
      | source_type_name               | "source_type"                           |
      | source_schema_version          | 1                                       |
      | source_state (JSON in RawState)| (as above)                              |
      | source_private                 | (as above)                              |
      | source_identity (JSON in RawState)| (as above)                            |
      | source_identity_schema_version | 1                                       |
      | target_type_name               | "my_target_resource"                    |
    Then the response's target_state (DynamicValue, msgpack) should reflect `{"target_attr": "transformed_value_to_transform", "shared_id": "id-123"}`
    And the response's target_private data should be `{"target_meta": "new_info"}`
    And the response's target_identity (DynamicValue, msgpack) should reflect `{"target_identity_attr": "transformed_identity_val"}`
    And the response should not contain any error diagnostics

  Scenario: Successfully move and transform resource state to a compatible target type (JSON response)
    Given a source resource state (JSON) `{"source_field": "another_val", "id_field": "id-456"}` from "another_source_type" (schema version 0)
    And source private data `{"old_meta": "data"}`
    And source identity data (JSON) `{"old_identity": "old_id_val"}` (identity schema version 0)
    And the target provider "my_target_resource" can transform this into state `{"target_attr": "json_transformed_another_val", "shared_id": "id-456"}`
    And new target private data `{"new_meta_json": "new_data"}`
    And new target identity data `{"target_identity_attr": "json_transformed_old_id_val"}`
    And the provider will return the target state, private data, and identity encoded in JSON
    When a MoveResourceState request is made with details for "another_source_type" moving to "my_target_resource"
    Then the response's target_state (DynamicValue, JSON) should reflect `{"target_attr": "json_transformed_another_val", "shared_id": "id-456"}`
    And the response's target_private data should be `{"new_meta_json": "new_data"}`
    And the response's target_identity (DynamicValue, JSON) should reflect `{"target_identity_attr": "json_transformed_old_id_val"}`
    And the response should not contain any error diagnostics

  Scenario: Move resource state fails due to incompatible transformation
    Given a source resource state that cannot be meaningfully transformed to "my_target_resource" schema (e.g., missing critical data)
    When a MoveResourceState request is made to "my_target_resource" with this incompatible source state
    Then the response should contain an error diagnostic explaining the transformation failure (e.g., "Cannot map source_attr to target schema")
    And the target_state, target_private, and target_identity in the response may be null or empty

  Scenario: Handle gRPC error during MoveResourceState
    Given the provider's MoveResourceState RPC will return a gRPC error
    When a MoveResourceState request is made
    Then the overall operation should result in an error diagnostic reflecting the gRPC error

  Scenario: MoveResourceState to an unknown target resource type_name
    Given a MoveResourceState request is made with target_type_name "unknown_target_resource"
    When the MoveResourceState RPC is called on the target provider
    Then the response should contain an error diagnostic indicating "unknown_target_resource" is not a valid type for this provider.

  Scenario: Source state, private data, or identity is missing from the request
    # The RPC defines these as required. Core should always send them.
    # This tests provider robustness if it somehow receives an incomplete request.
    When a MoveResourceState request is made to "my_target_resource" but source_state is missing
    Then the provider should return an error diagnostic indicating an invalid request (e.g., "Missing source_state")
    # Similar scenarios for missing source_private, source_identity.

  Scenario: Transformation results in warnings but is otherwise successful
    Given a source resource state that can be transformed but with some ambiguities or defaults applied
    And the transformation to "my_target_resource" state is `{"target_attr": "transformed_with_defaults", "shared_id": "id-789"}`
    When a MoveResourceState request is made
    Then the response should contain the successfully transformed target_state, target_private, and target_identity
    And the response should also contain a warning diagnostic explaining the assumptions or defaults applied during transformation.

  Scenario: Source schema version is significantly different, requiring complex migration logic
    Given a source_schema_version is 0 and the source state is very old
    And the target "my_target_resource" (schema version 1) has logic to handle this large gap
    When a MoveResourceState request is made
    Then the transformation should proceed according to the provider's logic for that version jump
    And the response should reflect a successful move if the logic handles it.

  Scenario: Source identity schema version is different from source data schema version
    # The request has both source_schema_version and source_identity_schema_version.
    Given source_schema_version is 2 and source_identity_schema_version is 1
    And the provider can handle these distinct versions for data and identity transformation
    When a MoveResourceState request is made
    Then the transformation should use the respective versions correctly
    And the response should be successful if the transformation logic is sound.

  Scenario: Move operation where target state has fewer attributes than source (data loss if not handled)
    Given source state has `{"attr1": "v1", "attr_to_drop": "v_drop", "id": "id-loss"}`
    And "my_target_resource" schema only has `{"target_attr1": "string", "shared_id": "string"}`
    And the provider transforms this as `{"target_attr1": "v1", "shared_id": "id-loss"}` (dropping "attr_to_drop")
    When a MoveResourceState request is made
    Then the response should contain the transformed target_state
    And it may contain a warning diagnostic about "attr_to_drop" not being mapped if that's provider policy.

  Scenario: Move operation where target state has more attributes (new attributes get defaults or are computed)
    Given source state is `{"id": "id-gain"}`
    And "my_target_resource" schema has `{"shared_id": "string", "new_computed_target_attr": "string"}`
    And the provider transforms and computes to `{"shared_id": "id-gain", "new_computed_target_attr": "computed_on_move"}`
    When a MoveResourceState request is made
    Then the response should contain the transformed target_state including the new computed attribute.

  Scenario: Diagnostic message from move includes a specific path if relevant
    # Path context might be less common here as it's a whole-object transformation.
    # But a diagnostic could refer to a problematic source attribute.
    Given a source state attribute "problematic_source_field" causes an issue during transformation
    When a MoveResourceState request is made
    Then the response may contain a diagnostic
    And that diagnostic's attribute_path could reference "problematic_source_field" from the source context if useful.

  Scenario: Source provider address is for a different provider
    # The `source_provider_address` field informs the target provider about the origin.
    # The target provider might have specific logic for moves from known other providers.
    Given the source_provider_address is "registry.terraform.io/some-other/known-provider"
    And the target provider has special transformation rules for states coming from "known-provider"
    When a MoveResourceState request is made
    Then the target provider should apply these special rules during transformation.

  Scenario: Source RawState for state or identity uses flatmap encoding
    # Proto comments suggest JSON for source_state/identity in MoveResourceState as it's a newer RPC.
    # This tests robustness if flatmap were encountered in RawState, though unlikely.
    Given a source_state is provided via `RawState.flatmap` (e.g. `{"key": "val"}`)
    When a MoveResourceState request is made
    Then the target provider should ideally still attempt to process it if its RawState unmarshaling supports flatmap.
    And if not supported for this RPC by the provider, it should return an error diagnostic.
    # A clear error is preferable to silent failure or misinterpretation.

  Scenario: MoveResourceState results in empty target_private data
    Given a transformation where the target resource does not require or generate any private metadata
    When a MoveResourceState request is made
    Then the response's target_private field should be empty (nil or zero-length byte slice).

  Scenario: MoveResourceState results in empty target_identity data
    # Unlikely for most resources, but theoretically possible if identity becomes vacuous or is fully embedded in state.
    Given a transformation where the target resource's identity is fully represented by its state and no separate identity data is needed
    When a MoveResourceState request is made
    Then the response's target_identity.identity_data might be empty/null.
    # More typically, it would have some computed or transformed identity.
