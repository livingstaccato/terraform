# Metadata:
#   Covers: internal/plugin6/grpc_provider_test.go
#   Tests:
#     - TestGRPCProvider_GetSchema_ListResourceTypes (for schema definition)
#     - TestGRPCProvider_ListResource
#     - TestGRPCProvider_ListResource_Error
#     - TestGRPCProvider_ListResource_Diagnostics
#     - TestGRPCProvider_ListResource_Limit
#   Also covers aspects of ListResource.Request and ListResource.Event from proto.

Feature: ListResource RPC and Schema
  As a Terraform plugin,
  I need to define schemas for listable resource types and respond to ListResource requests
  So that Terraform core can discover and enumerate instances of these resources based on configuration.

  Background:
    Given a configured tfplugin6 gRPC provider server
    And the provider defines a list resource type "my_listable_items"
    And its schema (via GetProviderSchema) defines:
      - A "config" block with attribute "filter_text" (string, optional)
      - A "data" block (computed) which is a list of objects, where each object has:
        - "identity" (object, computed, from ResourceIdentityData)
        - "state" (object, computed, from DynamicValue, representing the resource object if requested)
        - "display_name" (string, computed)

  Scenario: Successfully list resources with identity only
    Given a ListResource request for "my_listable_items" with config `{"filter_text": "active"}` and `include_resource_object = false`
    And the provider finds two matching items:
      1. display_name "Item Alpha", identity `{"id": "alpha-001"}`
      2. display_name "Item Beta", identity `{"id": "beta-002"}`
    When the ListResource RPC is called as a stream
    Then the stream should yield two events:
      | display_name | identity               | resource_object |
      | Item Alpha   | `{"id": "alpha-001"}`  | (null)          |
      | Item Beta    | `{"id": "beta-002"}`   | (null)          |
    And the stream should then end (EOF)
    And no errors or diagnostics should be reported for these events or overall.

  Scenario: Successfully list resources including the full resource object
    Given a ListResource request for "my_listable_items" with config `{"filter_text": "all"}` and `include_resource_object = true`
    And the provider finds one matching item:
      1. display_name "Full Item Gamma", identity `{"id": "gamma-003"}`, resource object `{"id": "gamma-003", "status": "available", "details": "more data"}`
    When the ListResource RPC is called as a stream
    Then the stream should yield one event:
      | display_name    | identity               | resource_object (decoded)                                                     |
      | Full Item Gamma | `{"id": "gamma-003"}`  | `{"id": "gamma-003", "status": "available", "details": "more data"}`          |
    And the stream should then end (EOF)
    And no errors should be reported.

  Scenario: List resources with a limit, and more items are available than the limit
    Given a ListResource request for "my_listable_items" with `limit = 2`
    And the provider finds three matching items (Item A, Item B, Item C)
    When the ListResource RPC is called as a stream
    Then the stream should yield events for Item A and Item B
    And the stream should then end (EOF) after two events, without yielding Item C.

  Scenario: List resources with a limit, and fewer items are available than the limit
    Given a ListResource request for "my_listable_items" with `limit = 5`
    And the provider finds two matching items (Item X, Item Y)
    When the ListResource RPC is called as a stream
    Then the stream should yield events for Item X and Item Y
    And the stream should then end (EOF) after two events.

  Scenario: List resources results in no items found
    Given a ListResource request for "my_listable_items" with config `{"filter_text": "non_matching_filter"}`
    And the provider finds no items matching this filter
    When the ListResource RPC is called as a stream
    Then the stream should immediately end (EOF) without yielding any events
    And no errors should be reported.

  Scenario: ListResource stream returns an event with a diagnostic (warning or error)
    Given a ListResource request for "my_listable_items"
    And the provider finds an item "Problem Item Delta" but encounters a non-fatal issue reading its full details, generating a warning "Could not retrieve full details for Delta"
    And another item "Error Item Epsilon" causes a processing error "Failed to process Epsilon due to corruption"
    When the ListResource RPC is called as a stream
    Then the stream should yield an event for "Problem Item Delta" with its identity and the warning diagnostic
    And the stream may yield an event for "Error Item Epsilon" with an error diagnostic (or the error might terminate the stream earlier)
    # The behavior for item-specific errors can vary: either an event with an error, or stream termination.

  Scenario: ListResource RPC itself fails with a gRPC error before streaming starts
    Given the provider's ListResource RPC will return a gRPC error (e.g., authentication failure before streaming)
    When the ListResource RPC is called
    Then the operation to establish the stream should fail with an error diagnostic reflecting the gRPC error
    And no events should be received.

  Scenario: ListResource stream fails with a gRPC error mid-stream
    Given a ListResource request for "my_listable_items"
    And the provider starts streaming items successfully
    And after streaming one item, a gRPC error occurs (e.g., connection lost)
    When the ListResource RPC is called as a stream
    Then the stream should yield the first item
    And then the attempt to receive the next item should fail with an error diagnostic reflecting the gRPC error.

  Scenario: ListResource for an unknown list resource type_name
    Given a ListResource request is made for an unknown type "unknown_listable_type"
    When the ListResource RPC is called
    Then the operation to establish the stream should fail with an error diagnostic indicating "unknown_listable_type" is not valid.

  Scenario: ListResource schema definition in GetProviderSchema (as per TestGRPCProvider_GetSchema_ListResourceTypes)
    # This tests that the schema for the list resource type is correctly reported by GetProviderSchema.
    Given the provider "my_listable_items" has its schema defined as:
      - Config block: "config" with attribute "filter_attr" (string, required by test setup, but made optional for background)
      - Data block (computed list): each item has "state" (object, from resource schema) and "identity" (object, from identity schema)
    When GetProviderSchema RPC is called
    Then the response's list_resource_schemas for "my_listable_items" should correctly reflect this structure
    Including the "config" block with "filter_attr" and a "data" attribute representing the list output structure.
    # The 'data' attribute in the Go test is implicitly handled by the framework to structure the output.
    # The BDD should verify the list resource schema itself (config part) and how results are expected.

  Scenario: ListResource with empty config when all config attributes are optional
    Given the "my_listable_items" schema's "config" block has "filter_text" as optional
    And a ListResource request for "my_listable_items" with empty config `{}`
    And the provider lists all items when the filter is empty
    When the ListResource RPC is called
    Then the stream should yield all available items without error.

  Scenario: ListResource where resource_object or identity data uses msgpack/JSON
    Given a ListResource request for "my_listable_items" with `include_resource_object = true`
    And an item's identity is `{"id": "item-mpk"}` (to be msgpack encoded in event)
    And its resource object is `{"detail": "msgpack_data"}` (to be msgpack encoded in event)
    When the ListResource RPC is called
    Then an event in the stream should have its identity.identity_data.msgpack populated
    And its resource_object.msgpack populated.
    # Similar test can be done for JSON encoding if provider chooses that.

  Scenario: ListResource event display_name contains special characters
    Given a ListResource request for "my_listable_items"
    And an item has display_name "Item with /slashes & ampersands/"
    When the ListResource RPC is called
    Then an event in the stream should correctly reflect this display_name.

  Scenario: ListResource where the underlying resource schema for 'state' is complex
    Given the schema for items listed by "my_listable_items" (i.e., the schema for the 'state' attribute) is complex, with nested blocks and various types
    And `include_resource_object = true`
    And an item's state is `{"id": "complex-item", "nested_block": {"attr": "val"}, "list_attr": ["a", "b"]}`
    When the ListResource RPC is called
    Then an event's resource_object, when decoded, should accurately represent this complex structure.

  Scenario: ListResource where the identity schema for 'identity' is complex
    Given the identity schema for items listed by "my_listable_items" is complex (e.g., multiple identity attributes)
    And an item's identity is `{"main_id": "main", "secondary_id": "secondary"}`
    When the ListResource RPC is called
    Then an event's identity, when decoded, should accurately represent this complex identity structure.

  Scenario: ListResource called with limit = 0
    # Behavior for limit=0 can vary: list all, list none, or error.
    # Assuming "list all" or "provider default" if proto doesn't specify.
    # Terraform typically uses limit > 0 if specified. If 0 means "no limit" by convention:
    Given a ListResource request for "my_listable_items" with `limit = 0`
    And the provider interprets limit=0 as "no limit" and finds 3 items
    When the ListResource RPC is called
    Then the stream should yield all 3 items.
    Alternatively, if limit=0 means "list none":
    Then the stream should yield no items.
    # The exact behavior for limit=0 should be clarified by protocol or provider documentation.
    # TestGRPCProvider_ListResource_Limit uses limit=2.

  Scenario: ListResource called with negative limit
    Given a ListResource request for "my_listable_items" with `limit = -1`
    When the ListResource RPC is called
    Then the provider should treat this as an invalid limit
    And the stream establishment should fail with an error diagnostic (e.g., "Invalid limit value").
    # Or the stream might return an event with an error diagnostic.

  Scenario: ListResource config is null
    Given the "my_listable_items" schema's "config" block has "filter_text" as optional
    And a ListResource request for "my_listable_items" with null config
    When the ListResource RPC is called
    Then the provider should treat null config as equivalent to empty config (all optionals take defaults or are unset)
    And the stream should yield items as if an empty config was provided.
