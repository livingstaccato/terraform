# Metadata:
#   Covers: internal/plugin6/grpc_provider_test.go
#   Tests:
#     - TestGRPCProvider_ApplyResourceChange
#     - TestGRPCProvider_ApplyResourceChangeJSON

Feature: ApplyResourceChange RPC
  As a Terraform plugin,
  I need to respond to ApplyResourceChange requests
  So that Terraform core can instruct me to create, update, or delete a managed resource based on a prior plan.

  Background:
    Given a configured tfplugin6 gRPC provider server
    And the provider defines a managed resource type "my_applied_resource"
    And its schema includes attributes "id" (string, computed), "current_value" (string), "sensitive_data" (string, sensitive)

  Scenario: Successfully apply a resource creation
    Given a planned state for creating "my_applied_resource" is `{"current_value": "new_resource_val", "id": "(known after apply)"}`
    And the provider successfully creates the resource remotely, resulting in actual state `{"id": "newly-created-id", "current_value": "new_resource_val"}`
    And the provider will return the new state and new identity encoded in msgpack
    When an ApplyResourceChange request is made with null prior_state, the planned_state, and relevant config and planned_private data
    Then the response should contain the new_state as DynamicValue (msgpack) reflecting `{"id": "newly-created-id", "current_value": "new_resource_val"}`
    And the response should contain the new_identity reflecting the created resource's identity (e.g., `{"id": "newly-created-id"}`)
    And the response may contain new private (meta) data if generated during creation
    And the response should not contain any error diagnostics

  Scenario: Successfully apply a resource update (in-place)
    Given a prior state for "my_applied_resource" is `{"id": "existing-id", "current_value": "old_val"}`
    And the planned state for updating it is `{"id": "existing-id", "current_value": "updated_val"}`
    And the provider successfully updates the resource remotely to match the planned state
    And the provider will return the new state and new identity encoded in JSON
    When an ApplyResourceChange request is made with the prior_state, planned_state, config, and planned_private data
    Then the response should contain the new_state as DynamicValue (JSON) reflecting `{"id": "existing-id", "current_value": "updated_val"}`
    And the new_identity should reflect the identity of the updated resource (usually unchanged for in-place updates)
    And the response should not contain any error diagnostics

  Scenario: Successfully apply a resource destruction
    # Destruction is usually an update where planned_state is null.
    Given a prior state for "my_applied_resource" is `{"id": "to-be-deleted-id", "current_value": "some_val"}`
    And the planned state for "my_applied_resource" is null (indicating destruction)
    And the provider successfully deletes the resource remotely
    When an ApplyResourceChange request is made with the prior_state, null planned_state, config, and planned_private data
    Then the response's new_state should be a null DynamicValue for the resource type
    And the new_identity might also be null or reflect the identity of the just-deleted resource
    And the response should not contain any error diagnostics

  Scenario: Apply operation results in an error (e.g., API failure, conflict)
    Given a planned state for creating "my_applied_resource" is `{"current_value": "error_case_val"}`
    And the provider encounters an API error trying to create the resource
    When an ApplyResourceChange request is made
    Then the response should contain an error diagnostic explaining the apply failure (e.g., "API Error: Resource creation forbidden")
    And the new_state in the response might be null or reflect a partially created state if applicable (though null is common on error)

  Scenario: Handle gRPC error during ApplyResourceChange
    Given the provider's ApplyResourceChange RPC will return a gRPC error
    When an ApplyResourceChange request is made
    Then the overall operation should result in an error diagnostic reflecting the gRPC error

  Scenario: ApplyResourceChange request includes provider_meta, planned_private, planned_identity, and config
    Given a planned state for "my_applied_resource"
    And the ApplyResourceChange request includes provider_meta, config, planned_private data, and planned_identity
    When an ApplyResourceChange request is made with all these fields populated
    Then the provider should use provider_meta for its configuration context
    And use config to understand the desired end-state attributes
    And use planned_private for any internal continuity from the plan
    And use planned_identity to target the correct resource if applicable (especially for updates/deletes)
    And the apply should proceed, returning a new_state, private data, and new_identity.

  Scenario: ApplyResourceChange returns updated private (meta) data
    Given applying a change to "my_applied_resource" updates some internal metadata (e.g., etag)
    When an ApplyResourceChange request is made
    Then the response's private field should contain the new private meta-data bytes.

  Scenario: ApplyResourceChange returns a new_identity
    Given "my_applied_resource" is created or its identity is refined during apply
    When an ApplyResourceChange request is made
    Then the response's new_identity should reflect the actual, concrete identity of the resource post-apply.

  Scenario: Legacy type system flag is set by a legacy SDK based provider during apply
    # This is a specific flag for Terraform's internal legacy SDK.
    Given a provider built with the legacy SDK sets the legacy_type_system flag in its ApplyResourceChange response
    When an ApplyResourceChange request is made to this provider
    Then the response should include `legacy_type_system = true`
    And Terraform Core should interpret this accordingly.
    # Modern SDKs should NOT set this.

  Scenario: Diagnostic message from apply includes a specific attribute path
    # While less common for apply (errors are often resource-level), a diagnostic might still relate to an attribute.
    Given applying a change to "my_applied_resource" has an issue related to "sensitive_data" processing post-API call
    When an ApplyResourceChange request is made
    Then the response may contain a diagnostic (error or warning)
    And that diagnostic's attribute_path could point to "sensitive_data" if relevant.

  Scenario: Apply for a resource type not known by the provider
    Given an ApplyResourceChange request is made for type_name "unknown_resource_type"
    When the ApplyResourceChange RPC is called
    Then the response should contain an error diagnostic indicating "unknown_resource_type" is not valid.

  Scenario: ApplyResourceChange when prior_state and planned_state are identical (no-op apply)
    # This implies the plan found no changes, so apply should also be a no-op.
    Given prior_state and planned_state for "my_applied_resource" are identical: `{"id": "no-change-id", "current_value": "stable_val"}`
    When an ApplyResourceChange request is made
    Then the response's new_state should be identical to the planned_state
    And the response should not contain any error diagnostics.
    # The provider might not even make API calls if it detects no effective change.

  Scenario: ApplyResourceChange when prior_state is null and planned_state is also null
    # This represents a resource that was not planned to exist and wasn't in state.
    # Apply should be a no-op.
    When an ApplyResourceChange request is made with null prior_state and null planned_state
    Then the response's new_state should also be null
    And no errors should be indicated.

  Scenario: Sensitive data handling during apply
    Given the planned state for "my_applied_resource" includes `{"sensitive_data": "super_secret"}`
    And the provider applies this change
    And the actual resulting state also has `{"sensitive_data": "super_secret"}` (or its representation if transformed by API)
    When an ApplyResourceChange request is made
    Then the new_state in the response should contain `{"sensitive_data": "super_secret"}`
    And Terraform core is responsible for ensuring this sensitive data is handled appropriately (e.g., not displayed in UI logs).
    # The provider's role is to set the value in the state.

  Scenario: Provider returns an inconsistent new_state compared to planned_state after apply (e.g. API modified values unexpectedly)
    Given the planned state for "my_applied_resource" is `{"id": "res-drift", "current_value": "planned_val"}`
    But after the API call, the remote resource has `{"id": "res-drift", "current_value": "api_modified_val"}`
    When an ApplyResourceChange request is made
    Then the new_state in the response should reflect the actual remote state: `{"id": "res-drift", "current_value": "api_modified_val"}`
    And the provider may issue a warning diagnostic about the drift if it's unexpected.

  Scenario: ApplyResourceChange uses config from request to influence behavior
    Given a planned state for "my_applied_resource" and a config value `{"feature_toggle": true}` in the ApplyResourceChange request
    And the provider's apply logic for "my_applied_resource" behaves differently if `config.feature_toggle` is true
    When an ApplyResourceChange request is made with this config
    Then the provider should use `config.feature_toggle` to guide its API interaction
    And the resulting new_state should reflect the outcome of this conditional logic.

  Scenario: Apply operation takes a significant amount of time
    # The RPC itself is synchronous from core's perspective. Timeout handling is core's responsibility or via context cancellation.
    Given applying "my_applied_resource" involves a long-running remote operation
    When an ApplyResourceChange request is made
    Then the provider executes the long-running operation
    And eventually returns a response (success or failure) once the operation completes or times out internally (if provider implements its own sub-timeouts).
    # BDD step would focus on "Then the response is eventually received with the outcome of the apply operation".

  Scenario: ApplyResourceChange for a resource that was deleted out-of-band between plan and apply
    Given a prior_state for "my_applied_resource" `{"id": "res-vanished"}`
    And a planned_state to update it `{"id": "res-vanished", "current_value": "update_val"}`
    But the resource "res-vanished" was deleted from the remote system after the plan was created
    When an ApplyResourceChange request is made
    Then the provider's attempt to update "res-vanished" will likely fail (e.g., "resource not found" API error)
    And the response should contain an error diagnostic reflecting this failure.
    # Or, if the provider's logic is to "create if not found on update", it might recreate it,
    # but that's less common and depends on provider design. An error is typical.
