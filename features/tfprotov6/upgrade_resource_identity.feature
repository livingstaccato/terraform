# Metadata:
#   Covers: internal/plugin6/grpc_provider_test.go
#   Tests:
#     - TestGRPCProvider_UpgradeResourceIdentity

Feature: UpgradeResourceIdentity RPC
  As a Terraform plugin,
  I need to respond to UpgradeResourceIdentity requests
  So that Terraform core can migrate resource identity data from an older identity schema version to the current one.

  Background:
    Given a configured tfplugin6 gRPC provider server
    And the provider defines a managed resource type "my_resource"
    And the current resource identity schema version for "my_resource" is 2
    And this identity schema (version 2) expects attributes like `{"new_id_attr": "string", "region_code": "string"}`

  Scenario: Successfully upgrade resource identity from an older version
    Given the prior resource identity schema version for "my_resource" was 1
    And an old resource identity for "my_resource" (version 1) is `{"old_id_attr": "value_v1", "location": "us-west"}` (JSON encoded)
    And the provider logic can upgrade this to current identity schema version 2 as `{"new_id_attr": "value_v1_migrated", "region_code": "usw"}`
    When an UpgradeResourceIdentity request is made for "my_resource" from version 1 with the old raw identity
    Then the response should contain the upgraded identity data
    And this upgraded identity data, when decoded against identity schema version 2, should be `{"new_id_attr": "value_v1_migrated", "region_code": "usw"}`
    And the response should not contain any error diagnostics

  Scenario: Upgrade resource identity when the identity is already at the current version
    Given a resource identity for "my_resource" is already at the current identity schema version 2: `{"new_id_attr": "current_id", "region_code": "use"}`
    When an UpgradeResourceIdentity request is made for "my_resource" from version 2 with this raw identity
    Then the response should contain the same identity data `{"new_id_attr": "current_id", "region_code": "use"}`
    And the response should not contain any error diagnostics

  Scenario: Upgrade resource identity results in errors (e.g., incompatible change)
    Given the prior resource identity schema version for "my_resource" was 0
    And an old resource identity for "my_resource" (version 0) is `{"very_old_identifier": "unmigratable_id"}`
    And the provider logic determines this identity cannot be safely upgraded to version 2
    When an UpgradeResourceIdentity request is made for "my_resource" from version 0 with the old raw identity
    Then the response should contain an error diagnostic explaining the upgrade failure
    And the upgraded_identity in the response might be null or its data empty

  Scenario: Upgrade resource identity results in warnings
    Given the prior resource identity schema version for "my_resource" was 1
    And an old resource identity for "my_resource" (version 1) is `{"ambiguous_id_part": "data"}`
    And the provider logic upgrades this to `{"new_id_attr": "data_assumed_default_id"}` for identity schema version 2, with an assumption
    When an UpgradeResourceIdentity request is made for "my_resource" from version 1 with the old raw identity
    Then the response should contain the upgraded identity data `{"new_id_attr": "data_assumed_default_id"}`
    And the response should contain a warning diagnostic explaining the assumption made
    And the response should not contain any error diagnostics

  Scenario: Handle gRPC error during UpgradeResourceIdentity
    Given the provider's UpgradeResourceIdentity RPC will return a gRPC error for "my_resource"
    And an UpgradeResourceIdentity request is made for "my_resource"
    When the UpgradeResourceIdentity RPC is called
    Then the overall operation should result in an error diagnostic reflecting the gRPC error

  Scenario: Upgrade resource identity for an unknown resource type_name
    Given an UpgradeResourceIdentity request is made for an unknown type "unknown_resource" from version 0
    When the UpgradeResourceIdentity RPC is called
    Then the response should contain an error diagnostic indicating "unknown_resource" is not a valid type

  Scenario: Input raw_identity uses legacy flatmap format (though proto suggests JSON for new RPCs)
    # The MoveResourceState proto mentions RawState.json only for source_state/identity, implying flatmap is less expected for new RPCs.
    # However, RawState still has the flatmap option. Testing this for completeness if a provider were to encounter it.
    Given the prior resource identity schema version for "my_resource" was 0 (legacy)
    And an old resource identity for "my_resource" (version 0) is provided in flatmap format: `{"id_part1": "val1", "id_part2": "val2"}`
    And the provider logic can upgrade this flatmap identity to current identity schema version 2 as `{"new_id_attr": "val1-val2"}`
    When an UpgradeResourceIdentity request is made for "my_resource" from version 0 with the old raw identity (flatmap encoded in RawState)
    Then the response should contain the upgraded identity data
    And this upgraded identity data, when decoded, should be `{"new_id_attr": "val1-val2"}`
    And the response should not contain any error diagnostics

  Scenario: Input raw_identity JSON is malformed
    Given an UpgradeResourceIdentity request is made for "my_resource" from version 1
    And the provided raw_identity JSON is malformed (e.g., `{"id_attr": "unterminated_string`)
    When the UpgradeResourceIdentity RPC is called with this malformed raw JSON identity
    Then the response should contain an error diagnostic indicating issues decoding the prior identity
    # Or the provider's JSON unmarshaling would fail.

  Scenario: Diagnostic message from identity upgrade includes a specific attribute path
    # Identity attributes are usually direct, but a path might be relevant if structure was more complex.
    Given an old resource identity for "my_resource" version 1 is `{"problem_id_attr": "needs_attention"}`
    And upgrading "problem_id_attr" causes a warning or error related to that specific attribute
    When an UpgradeResourceIdentity request is made for "my_resource" from version 1
    Then the response should contain a diagnostic (error or warning)
    And that diagnostic's attribute_path should point to "problem_id_attr" (or its new path)

  Scenario: Request version for identity is higher than provider's current identity schema version
    Given the current resource identity schema version for "my_resource" is 2
    And an UpgradeResourceIdentity request is made for "my_resource" from version 3 (future version) with some identity data
    When the UpgradeResourceIdentity RPC is called
    Then the response should contain an error diagnostic indicating an invalid request (e.g. "cannot upgrade identity from future version")

  Scenario: Upgraded identity data uses JSON encoding in DynamicValue
    # The TestGRPCProvider_UpgradeResourceIdentity test cases show response with JSON.
    Given the prior resource identity schema version for "my_resource" was 1
    And an old resource identity is `{"id": "old"}`
    And the provider upgrades it to `{"new_id_attr": "new_id_from_old"}` for version 2
    When an UpgradeResourceIdentity request is made
    And the provider returns the upgraded identity with DynamicValue.json populated
    Then the response's upgraded_identity.identity_data.json should contain the JSON bytes for `{"new_id_attr": "new_id_from_old"}`.

  Scenario: Upgraded identity data uses msgpack encoding in DynamicValue
    Given the prior resource identity schema version for "my_resource" was 1
    And an old resource identity is `{"id": "old"}`
    And the provider upgrades it to `{"new_id_attr": "new_id_from_old_mp"}` for version 2
    When an UpgradeResourceIdentity request is made
    And the provider returns the upgraded identity with DynamicValue.msgpack populated
    Then the response's upgraded_identity.identity_data.msgpack should contain the msgpack bytes for `{"new_id_attr": "new_id_from_old_mp"}`.

  Scenario: Provider returns no upgraded identity but provides diagnostics
    Given an old resource identity that leads to a non-fatal warning during upgrade
    And the provider decides not to return an upgraded identity but only a warning diagnostic
    When an UpgradeResourceIdentity request is made
    Then the response's upgraded_identity field might be null or its identity_data empty
    And the response should contain the warning diagnostic.
    # This covers cases where an upgrade might be ambiguous but not a hard error.
    # TestGRPCProvider_UpgradeResourceIdentity has a case `response with error diagnostic` where value is nil.

  Scenario: Resource identity schema mismatch leads to upgrade error
    # Covered by TestGRPCProvider_UpgradeResourceIdentity "schema mismatch" case
    Given the prior resource identity schema version for "my_resource" was 1
    And an old resource identity is `{"old_attr": "bar"}`
    And the provider attempts to upgrade this, but the resulting data `{"attr_new": "bar"}` does not match the target identity schema version 2
    When an UpgradeResourceIdentity request is made
    Then the response should contain an error diagnostic indicating a schema mismatch or decoding error for the upgraded identity.
    And the upgraded_identity in the response may be null or its data empty.
