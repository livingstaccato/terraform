# Metadata:
#   Covers: internal/plugin6/grpc_provider_test.go
#   Tests:
#     - TestGRPCProvider_ReadResource
#     - TestGRPCProvider_ReadResource_deferred
#     - TestGRPCProvider_ReadResourceJSON
#     - TestGRPCProvider_ReadEmptyJSON

Feature: ReadResource RPC
  As a Terraform plugin,
  I need to respond to ReadResource requests
  So that Terraform core can refresh the state of a managed resource from the remote system.

  Background:
    Given a configured tfplugin6 gRPC provider server
    And the provider defines a managed resource type "my_existing_resource"
    And its schema includes attributes like "id" (string, computed), "config_attr" (string), "status" (string, computed)

  Scenario: Successfully read an existing resource and return its current state (msgpack)
    Given a "my_existing_resource" with prior state `{"id": "res-123", "config_attr": "value_in_tf_state"}`
    And its current remote state is `{"id": "res-123", "config_attr": "value_in_tf_state", "status": "active_remote"}`
    And the provider will return the new state and new identity encoded in msgpack
    When a ReadResource request is made for "my_existing_resource" with the prior state and current identity
    Then the response should contain the new_state as DynamicValue (msgpack) reflecting `{"id": "res-123", "config_attr": "value_in_tf_state", "status": "active_remote"}`
    And the response should contain the new_identity if it changed or was refined
    And the response should not contain any error diagnostics

  Scenario: Successfully read an existing resource and return its current state (JSON)
    Given a "my_existing_resource" with prior state `{"id": "res-xyz", "config_attr": "value_in_tf_state_json"}`
    And its current remote state is `{"id": "res-xyz", "config_attr": "value_in_tf_state_json", "status": "updated_remote"}`
    And the provider will return the new state and new identity encoded in JSON
    When a ReadResource request is made for "my_existing_resource" with the prior state and current identity
    Then the response should contain the new_state as DynamicValue (JSON) reflecting `{"id": "res-xyz", "config_attr": "value_in_tf_state_json", "status": "updated_remote"}`
    And the response should contain the new_identity if it changed or was refined
    And the response should not contain any error diagnostics

  Scenario: Read a resource that no longer exists remotely (returns null state)
    Given a "my_existing_resource" with prior state `{"id": "res-gone", "config_attr": "some_value"}`
    And the resource "res-gone" has been deleted from the remote system
    And the provider will return an empty/null new state (e.g., empty JSON `""` or msgpack for null)
    When a ReadResource request is made for "my_existing_resource" with the prior state and current identity
    Then the response's new_state should represent a null object of the resource type
    And the response's new_identity might be null or unchanged
    And the response should not contain any error diagnostics
    # Terraform core interprets a null new_state as the resource needing to be recreated.

  Scenario: Read operation is deferred by the provider
    Given a "my_existing_resource" with prior state `{"id": "res-defer", "config_attr": "defer_value"}`
    And the provider needs to defer the read operation (e.g., waiting for another resource, provider config unknown)
    And the provider will return a deferred response with reason ABSENT_PREREQ
    When a ReadResource request is made for "my_existing_resource" with the prior state and current identity
    Then the response should indicate the operation is deferred
    And the deferred reason should be ABSENT_PREREQ
    And the response may still contain a new_state (potentially partial or same as prior)
    And the response should not contain error diagnostics unless the deferral itself is an error condition being reported

  Scenario: Read resource encounters an error (e.g., API error, permission denied)
    Given a "my_existing_resource" with prior state `{"id": "res-error", "config_attr": "error_value"}`
    And reading the remote state for "res-error" fails due to an API error
    When a ReadResource request is made for "my_existing_resource"
    Then the response should contain an error diagnostic explaining the failure
    And the new_state in the response might be null or reflect the prior state (if no update could be made)

  Scenario: Handle gRPC error during ReadResource
    Given the provider's ReadResource RPC will return a gRPC error for "my_existing_resource"
    And a ReadResource request is made for "my_existing_resource"
    When the ReadResource RPC is called
    Then the overall operation should result in an error diagnostic reflecting the gRPC error

  Scenario: Read resource for an unknown resource type_name
    Given a ReadResource request is made for an unknown type "unknown_resource"
    When the ReadResource RPC is called
    Then the response should contain an error diagnostic indicating "unknown_resource" is not a valid type

  Scenario: ReadResource request includes provider_meta
    Given a "my_existing_resource" with prior state
    And the provider requires provider_meta data for API calls (e.g., `{"api_key": "key"}`)
    When a ReadResource request is made including this provider_meta
    Then the provider should use the provider_meta for its operations
    And the read should succeed if the meta and resource are valid, returning the new state

  Scenario: ReadResource request includes private state (meta)
    Given a "my_existing_resource" with prior state and some private meta-data `{"internal_id": "priv-123"}`
    When a ReadResource request is made including this private state
    Then the provider should use this private state to aid in reading the resource
    And the response may include updated private state if necessary
    And the read should succeed, returning the new state

  Scenario: ReadResource request includes client capabilities
    Given a "my_existing_resource" with prior state
    And the ReadResource request includes client capabilities (e.g. `deferral_allowed = true`)
    When a ReadResource request is made
    Then the provider should acknowledge these client capabilities
    And if the provider supports deferral and the client allows it, a deferred response is permissible.
    And the read should otherwise proceed normally.

  Scenario: ReadResource returns updated private state (meta)
    Given a "my_existing_resource" with prior state
    And reading the resource updates some internal metadata tracked by the provider
    When a ReadResource request is made
    Then the response should contain the new_state
    And the response's private field should contain the updated private meta-data bytes

  Scenario: ReadResource request with current_identity provided
    Given a "my_existing_resource" with prior state and a known current_identity `{"unique_id": "remote-identifier"}`
    When a ReadResource request is made including this current_identity
    Then the provider should use this current_identity to locate and read the remote resource
    And the response should contain the new_state
    And the response should contain the new_identity (which might be the same as current_identity or updated)

  Scenario: ReadResource refines or updates resource identity
    Given a "my_existing_resource" with prior state and current_identity `{"old_format_id": "123"}`
    And the remote resource now has a canonical identity `{"canonical_id": "XYZ", "type": "specific"}`
    When a ReadResource request is made
    Then the response should contain the new_state
    And the response's new_identity should be the canonical identity `{"canonical_id": "XYZ", "type": "specific"}`

  Scenario: Prior state is null (e.g., resource being imported or just created and needs immediate read)
    # While ReadResource is usually for existing state, it might be called after an import placeholder is created.
    Given a "my_existing_resource" for which the prior_state in the request is null
    And its current remote state is `{"id": "res-new", "status": "available"}`
    And the request includes current_identity `{"id": "res-new"}`
    When a ReadResource request is made with null prior_state and the current_identity
    Then the response should contain the new_state reflecting `{"id": "res-new", "status": "available"}`
    And the response should contain the corresponding new_identity.

  Scenario: Diagnostic message from read includes a specific attribute path
    Given reading "my_existing_resource" encounters a recoverable issue with a specific attribute "feature_flag" (e.g., value changed unexpectedly)
    When a ReadResource request is made
    Then the response should contain a warning diagnostic
    And that diagnostic's attribute_path should point to "feature_flag"
    And the new_state should still be returned.

  Scenario: ReadResource returns a new_state with fewer attributes than schema (e.g. optional computed values not set)
    Given "my_existing_resource" schema has "attr1" (string) and "optional_computed_attr" (string, optional, computed)
    And remote state only provides "attr1": "value"
    When a ReadResource request is made
    Then the new_state in the response should be `{"attr1": "value"}` (optional_computed_attr might be null or absent)
    And this should be considered valid against the schema.

  Scenario: ReadResource returns a new_state with more attributes than in prior_state (new computed values)
    Given "my_existing_resource" prior state is `{"id": "res-789"}`
    And its remote state is `{"id": "res-789", "newly_computed_attr": "computed_value", "another_computed": 123}`
    When a ReadResource request is made
    Then the response's new_state should reflect `{"id": "res-789", "newly_computed_attr": "computed_value", "another_computed": 123}`.

  Scenario: ReadResource for a resource whose configuration has changed significantly but ID remains
    # ReadResource gets prior_state, not config. It should reflect remote truth.
    Given a "my_existing_resource" with prior state `{"id": "res-stable", "config_attr": "old_config_val"}`
    And its remote state is `{"id": "res-stable", "config_attr": "old_config_val", "status": "active_remote_despite_config_drift"}`
    # Assume config in TF files changed, but that's for Plan/Apply. Read just gets remote state.
    When a ReadResource request is made for "my_existing_resource" with the prior state
    Then the response should contain the new_state reflecting remote reality: `{"id": "res-stable", "config_attr": "old_config_val", "status": "active_remote_despite_config_drift"}`.
    # The "config_attr" in state should ideally match config if no drift, but read focuses on what's remote.
    # If config_attr itself changed on remote, that would be reflected.

  Scenario: ReadResource when client does not allow deferral
    Given a "my_existing_resource" with prior state
    And the ReadResource request includes client capabilities with `deferral_allowed = false`
    And the provider logic would normally defer this read operation
    When a ReadResource request is made
    Then the provider should not return a deferred response
    And the provider should attempt to complete the read, or return an error if it cannot proceed without deferral.
