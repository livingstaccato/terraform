# Metadata:
#   Covers: internal/plugin6/grpc_provider_test.go
#   Tests:
#     - TestGRPCProvider_UpgradeResourceState
#     - TestGRPCProvider_UpgradeResourceStateJSON

Feature: UpgradeResourceState RPC
  As a Terraform plugin,
  I need to respond to UpgradeResourceState requests
  So that Terraform core can migrate resource state from an older schema version to the current schema version.

  Background:
    Given a configured tfplugin6 gRPC provider server
    And the provider defines a managed resource type "my_resource"
    And the current schema version for "my_resource" is 2

  Scenario: Successfully upgrade resource state from an older version using msgpack
    Given the prior schema version for "my_resource" was 1
    And an old resource state for "my_resource" (version 1) is `{"old_attr": "value_v1", "common_attr": "shared"}`
    And the provider logic can upgrade this to current schema version 2 as `{"new_attr": "value_v1_migrated", "common_attr": "shared"}`
    When an UpgradeResourceState request is made for "my_resource" from version 1 with the old raw state (JSON encoded)
    And the provider returns the upgraded state encoded in msgpack
    Then the response should contain the upgraded state as a DynamicValue (msgpack)
    And this upgraded state, when decoded against schema version 2, should be `{"new_attr": "value_v1_migrated", "common_attr": "shared"}`
    And the response should not contain any error diagnostics

  Scenario: Successfully upgrade resource state from an older version using JSON
    Given the prior schema version for "my_resource" was 1
    And an old resource state for "my_resource" (version 1) is `{"old_attr": "value_v1", "common_attr": "shared"}`
    And the provider logic can upgrade this to current schema version 2 as `{"new_attr": "value_v1_migrated", "common_attr": "shared"}`
    When an UpgradeResourceState request is made for "my_resource" from version 1 with the old raw state (JSON encoded)
    And the provider returns the upgraded state encoded in JSON
    Then the response should contain the upgraded state as a DynamicValue (JSON)
    And this upgraded state, when decoded against schema version 2, should be `{"new_attr": "value_v1_migrated", "common_attr": "shared"}`
    And the response should not contain any error diagnostics

  Scenario: Upgrade resource state when the state is already at the current version
    # Providers might be called with current version if state was written by a buggy older core version, or for other reasons.
    # The typical expectation is to return the state as-is if versions match current schema.
    Given a resource state for "my_resource" is already at the current schema version 2: `{"current_attr": "value_v2"}`
    When an UpgradeResourceState request is made for "my_resource" from version 2 with this raw state
    Then the response should contain the same state `{"current_attr": "value_v2"}` as DynamicValue
    And the response should not contain any error diagnostics

  Scenario: Upgrade resource state results in errors (e.g., data loss, incompatible change)
    Given the prior schema version for "my_resource" was 0
    And an old resource state for "my_resource" (version 0) is `{"very_old_attr": "unmigratable"}`
    And the provider logic determines this state cannot be safely upgraded to version 2
    When an UpgradeResourceState request is made for "my_resource" from version 0 with the old raw state
    Then the response should contain an error diagnostic explaining the upgrade failure
    And the upgraded_state in the response might be null or empty

  Scenario: Upgrade resource state results in warnings (e.g., assumptions made)
    Given the prior schema version for "my_resource" was 1
    And an old resource state for "my_resource" (version 1) is `{"ambiguous_attr": "data"}`
    And the provider logic upgrades this to `{"new_attr": "data_assumed_default"}` for schema version 2, with an assumption
    When an UpgradeResourceState request is made for "my_resource" from version 1 with the old raw state
    Then the response should contain the upgraded state `{"new_attr": "data_assumed_default"}`
    And the response should contain a warning diagnostic explaining the assumption made during upgrade
    And the response should not contain any error diagnostics

  Scenario: Handle gRPC error during UpgradeResourceState
    Given the provider's UpgradeResourceState RPC will return a gRPC error for "my_resource"
    And an UpgradeResourceState request is made for "my_resource"
    When the UpgradeResourceState RPC is called
    Then the overall operation should result in an error diagnostic reflecting the gRPC error

  Scenario: Upgrade resource state for an unknown resource type_name
    Given an UpgradeResourceState request is made for an unknown type "unknown_resource" from version 0
    When the UpgradeResourceState RPC is called
    Then the response should contain an error diagnostic indicating "unknown_resource" is not a valid type
    # Or the provider might panic/error internally if it can't find schema info.

  Scenario: Input raw_state uses legacy flatmap format
    Given the prior schema version for "my_resource" was 0 (legacy)
    And an old resource state for "my_resource" (version 0) is provided in flatmap format: `{"attr1": "val1", "list.0": "item1"}`
    And the provider logic can upgrade this flatmap state to current schema version 2 as `{"new_attr1": "val1", "new_list": ["item1"]}`
    When an UpgradeResourceState request is made for "my_resource" from version 0 with the old raw state (flatmap encoded)
    Then the response should contain the upgraded state as a DynamicValue (e.g., msgpack)
    And this upgraded state, when decoded, should be `{"new_attr1": "val1", "new_list": ["item1"]}`
    And the response should not contain any error diagnostics

  Scenario: Input raw_state JSON is malformed
    Given an UpgradeResourceState request is made for "my_resource" from version 1
    And the provided raw_state JSON is malformed (e.g., `{"attr": "unterminated_string`)
    # Core Terraform would likely catch this before calling the provider.
    # However, if the provider receives it, it should handle it gracefully.
    When the UpgradeResourceState RPC is called with this malformed raw JSON state
    Then the response should contain an error diagnostic indicating issues decoding the prior state
    # Or the provider's JSON unmarshaling would fail, leading to an internal error reported as a diagnostic.

  Scenario: Upgrade path involves multiple intermediate schema versions
    # The RPC is for a single step upgrade from `request.version` to current schema.
    # If a provider internally handles multi-step, this is an implementation detail.
    # The BDD test focuses on the RPC contract.
    Given the current schema version for "my_resource" is 3
    And an old resource state is at version 0
    And the provider can upgrade from version 0 to 3 (possibly via internal steps 0->1, 1->2, 2->3)
    When an UpgradeResourceState request is made for "my_resource" from version 0 with the old state
    Then the response should contain the state upgraded to version 3
    And the response should not contain error diagnostics if the multi-step upgrade is successful.

  Scenario: Diagnostic message from upgrade includes a specific attribute path
    Given an old resource state for "my_resource" version 1 is `{"problem_attr": "needs_attention"}`
    And upgrading "problem_attr" causes a warning or error related to that specific attribute
    When an UpgradeResourceState request is made for "my_resource" from version 1
    Then the response should contain a diagnostic (error or warning)
    And that diagnostic's attribute_path should point to "problem_attr" (or the new path if renamed)

  Scenario: Request version is higher than provider's current schema version
    # This should ideally not happen if core and provider versions are managed correctly.
    Given the current schema version for "my_resource" is 2
    And an UpgradeResourceState request is made for "my_resource" from version 3 (future version) with some state
    When the UpgradeResourceState RPC is called
    Then the response should contain an error diagnostic indicating an invalid request (e.g. "cannot upgrade from future version")
    Or the provider might return the state as-is with a warning, depending on its robustness.
    # An error is more appropriate.

  Scenario: Upgrade results in an empty state (e.g. resource becomes effectively null/noop after schema change)
    Given the prior schema version for "my_resource" was 1 with state `{"old_meaningful_attr": "data"}`
    And the current schema version 2 makes this resource type obsolete or state irrelevant
    And the provider logic upgrades this to an empty or null state for schema version 2
    When an UpgradeResourceState request is made for "my_resource" from version 1
    Then the response should contain an upgraded_state that represents a null or empty object for "my_resource"
    And the response may contain a warning diagnostic explaining this outcome
    And the response should not contain error diagnostics.
