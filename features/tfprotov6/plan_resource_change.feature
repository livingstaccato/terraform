# Metadata:
#   Covers: internal/plugin6/grpc_provider_test.go
#   Tests:
#     - TestGRPCProvider_PlanResourceChange
#     - TestGRPCProvider_PlanResourceChangeJSON

Feature: PlanResourceChange RPC
  As a Terraform plugin,
  I need to respond to PlanResourceChange requests
  So that Terraform core can determine the actions needed to move from a prior resource state to a proposed new state based on configuration.

  Background:
    Given a configured tfplugin6 gRPC provider server
    And the provider defines a managed resource type "my_planned_resource"
    And its schema includes attributes "id" (string, computed), "config_value" (string), "updatable_attr" (string), "force_replace_attr" (string)

  Scenario: Plan a resource creation (no prior state)
    Given a "my_planned_resource" with no prior state (it's a new resource)
    And the proposed new state based on config is `{"config_value": "new_value", "updatable_attr": "initial_update"}`
    And the provider plans this as a create operation
    And the planned state will be `{"id": "(known after apply)", "config_value": "new_value", "updatable_attr": "initial_update"}` (ID is computed)
    And the provider will return the planned state and planned identity encoded in msgpack
    When a PlanResourceChange request is made with null prior_state, the proposed_new_state, and config
    Then the response should contain the planned_state as DynamicValue (msgpack)
    And the planned_state should reflect `{"id": "(known after apply)", "config_value": "new_value", "updatable_attr": "initial_update"}`
    And the response should contain the planned_private data if any
    And the response should contain the planned_identity (likely with some known-after-apply markers)
    And the response should not indicate requires_replace
    And the response should not contain any error diagnostics

  Scenario: Plan a resource update (in-place)
    Given a "my_planned_resource" with prior state `{"id": "res-1", "config_value": "val1", "updatable_attr": "old_update"}`
    And the proposed new state based on config is `{"config_value": "val1", "updatable_attr": "new_update"}` (only updatable_attr changes)
    And the provider plans this as an in-place update
    And the planned state will be `{"id": "res-1", "config_value": "val1", "updatable_attr": "new_update"}`
    And the provider will return the planned state and planned identity encoded in JSON
    When a PlanResourceChange request is made with the prior_state, proposed_new_state, and config
    Then the response should contain the planned_state as DynamicValue (JSON)
    And the planned_state should reflect `{"id": "res-1", "config_value": "val1", "updatable_attr": "new_update"}`
    And the response should not indicate requires_replace
    And the response should not contain any error diagnostics

  Scenario: Plan a resource replacement (attribute forces replacement)
    Given a "my_planned_resource" with prior state `{"id": "res-2", "config_value": "val2", "force_replace_attr": "old_force"}`
    And the proposed new state based on config is `{"config_value": "val2", "force_replace_attr": "new_force"}` (force_replace_attr changes)
    And the provider plans this as a replacement
    And the planned state will be `{"id": "(known after apply)", "config_value": "val2", "force_replace_attr": "new_force"}`
    When a PlanResourceChange request is made
    Then the response should contain the planned_state reflecting the new values with a computed ID
    And the response's requires_replace list should include the path to "force_replace_attr"
    And the response should not contain any error diagnostics

  Scenario: Plan a resource destruction (proposed new state is null)
    # This is handled if server capability "plan_destroy" is true.
    Given a "my_planned_resource" with prior state `{"id": "res-3", "config_value": "val3"}`
    And the proposed new state is null (resource is being removed from config)
    And the provider supports and expects plan_destroy capability
    And the provider plans this as a destruction
    And the planned state will be null
    When a PlanResourceChange request is made with prior_state, null proposed_new_state, and corresponding (likely empty) config
    Then the response's planned_state should be a null DynamicValue for the resource type
    And the response should not indicate requires_replace (destruction is not replacement)
    And the response should not contain any error diagnostics

  Scenario: Plan results in no changes (prior state and proposed state are effectively same)
    Given a "my_planned_resource" with prior state `{"id": "res-4", "config_value": "val4"}`
    And the proposed new state based on config is also `{"id": "res-4", "config_value": "val4"}`
    And the provider plans this as no-op
    And the planned state will be identical to the prior state
    When a PlanResourceChange request is made
    Then the response's planned_state should reflect `{"id": "res-4", "config_value": "val4"}`
    And the response should not indicate requires_replace
    And the response should not contain any error diagnostics

  Scenario: Plan operation is deferred by the provider
    Given a "my_planned_resource" with prior state and a proposed new state
    And the provider needs to defer the plan (e.g., config has unknown values, provider_config unknown)
    And the provider will return a deferred response with reason RESOURCE_CONFIG_UNKNOWN
    When a PlanResourceChange request is made
    Then the response should indicate the operation is deferred
    And the deferred reason should be RESOURCE_CONFIG_UNKNOWN
    And the response may contain a planned_state (potentially partial or reflecting proposed state with unknowns)
    And the response should not contain error diagnostics unless deferral is an error

  Scenario: Plan resource change encounters an error
    Given a "my_planned_resource" with prior state and a proposed new state that is invalid according to provider logic (e.g., conflicts)
    When a PlanResourceChange request is made
    Then the response should contain an error diagnostic explaining the planning failure
    And the planned_state in the response might be null or reflect the proposed state if partially processable

  Scenario: Handle gRPC error during PlanResourceChange
    Given the provider's PlanResourceChange RPC will return a gRPC error
    When a PlanResourceChange request is made
    Then the overall operation should result in an error diagnostic reflecting the gRPC error

  Scenario: PlanResourceChange request includes provider_meta, prior_private, client_capabilities, and prior_identity
    Given a "my_planned_resource" with prior state, prior_private data, and prior_identity
    And the PlanResourceChange request includes provider_meta and client_capabilities
    When a PlanResourceChange request is made with all these fields populated
    Then the provider should use provider_meta for its configuration context
    And use prior_private for any internal continuity
    And use prior_identity to understand the existing resource's identity
    And acknowledge client_capabilities
    And the plan should proceed based on all available information, returning a planned_state, planned_private, and planned_identity.

  Scenario: PlanResourceChange returns updated planned_private data
    Given a "my_planned_resource" planning operation requires updating internal metadata
    When a PlanResourceChange request is made
    Then the response's planned_private field should contain the new private meta-data bytes.

  Scenario: PlanResourceChange returns a planned_identity
    Given a "my_planned_resource" is being created or replaced
    And its identity will be determined upon apply (e.g. `{"id": "(known after apply)"}`)
    When a PlanResourceChange request is made
    Then the response's planned_identity should reflect this (potentially computed) identity.
    And if an update, planned_identity should reflect the existing or refined identity.

  Scenario: Legacy type system flag is set by a legacy SDK based provider
    # This is a specific flag for Terraform's internal legacy SDK.
    Given a provider built with the legacy SDK sets the legacy_type_system flag in its response
    When a PlanResourceChange request is made to this provider
    Then the response should include `legacy_type_system = true`
    And Terraform Core should interpret this accordingly.
    # Modern SDKs should NOT set this.

  Scenario: Diagnostic message from plan includes a specific attribute path
    Given a proposed change for "my_planned_resource" on "updatable_attr" is problematic
    When a PlanResourceChange request is made
    Then the response may contain a diagnostic (error or warning)
    And that diagnostic's attribute_path should point to "updatable_attr".

  Scenario: Plan indicates multiple attributes require replacement
    Given a "my_planned_resource" where changes to "force_replace_attr" and "another_force_replace_attr" both require replacement
    And the proposed new state changes both of these attributes
    When a PlanResourceChange request is made
    Then the response's requires_replace list should include paths to both "force_replace_attr" and "another_force_replace_attr".

  Scenario: Input proposed_new_state contains unknown values (needs apply-time computation)
    Given a "my_planned_resource" where `config_value` is derived from another resource's attribute not yet known `data.other_resource.output`
    And the proposed_new_state for "my_planned_resource" has `config_value = (unknown)`
    When a PlanResourceChange request is made
    Then the provider should plan with the unknown value, possibly making `planned_state.config_value` also unknown
    And if the provider cannot plan with unknowns and client doesn't allow deferral, it might error or defer (if client allows).
    And the planned_state should reflect any attributes that will be unknown until apply.

  Scenario: Plan for a resource type not known by the provider
    Given a PlanResourceChange request is made for type_name "unknown_resource_type"
    When the PlanResourceChange RPC is called
    Then the response should contain an error diagnostic indicating "unknown_resource_type" is not valid.

  Scenario: PlanResourceChange when prior_state is null and proposed_new_state is also null
    # This represents a scenario where a resource was never in state and is not in config.
    # Should ideally not be called, but if it is, provider should handle it gracefully.
    When a PlanResourceChange request is made with null prior_state and null proposed_new_state
    Then the response's planned_state should also be null
    And no errors or requires_replace should be indicated.
    And it should effectively be a no-op plan.

  Scenario: Provider uses different encoding for planned_state (JSON vs msgpack) than test default
    # Covered by specific JSON/msgpack scenarios for create/update.
    # This is to ensure flexibility in provider's choice of DynamicValue encoding.
    Given a plan results in a specific planned_state
    And the provider chooses to encode this planned_state using JSON in DynamicValue
    When a PlanResourceChange request is made
    Then the response's planned_state.json field should be populated with the correctly encoded JSON bytes.
    And if the provider chose msgpack, then planned_state.msgpack should be populated.

  Scenario: PlanResourceChange where config is null or empty but proposed_new_state is provided
    # Config might be empty if all values are defaulted by Terraform Core or derived from other sources.
    # proposed_new_state is the primary driver for planning changes from provider's perspective.
    Given a "my_planned_resource" with prior state `{"id": "res-config-empty", "config_value": "current"}`
    And the config in the request is empty `{}`
    And the proposed_new_state is `{"id": "res-config-empty", "config_value": "new_proposed_val"}`
    When a PlanResourceChange request is made
    Then the provider should plan based on proposed_new_state relative to prior_state
    And the planned_state should reflect `{"id": "res-config-empty", "config_value": "new_proposed_val"}` (if updatable).
    And the response should not contain errors due to empty config if proposed_new_state is valid.
