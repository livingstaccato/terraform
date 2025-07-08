# Source Go File: internal/addrs/map.go
# Source Go Test: internal/addrs/map_test.go

Feature: Addressable Item Map (addrs.Map)
  This feature describes the functionality of addrs.Map[V], a specialized map
  that uses addressable items (like LocalValue, InputVariable) as keys.
  It covers creation, putting, getting, checking for presence, removing items,
  and retrieving a snapshot of keys.

  Background:
    Given an addrs.Map for storing string values keyed by Referenceable addresses

  Scenario: Populating and querying an addrs.Map
    Given an addrs.Map is created with an initial element: Key InputVariable "name", Value "Aisling"
    When the following items are Put into the map:
      | KeyType     | KeyName | Value       |
      | LocalValue  | "hello" | "hello"     |
      | PathAttr    | "module"| "boop"      |
      | ModuleCall  | "beep"  | "unrealistic" |
    Then the map should Have the key InputVariable "name"
    And the map should Have the key LocalValue "hello"
    And the map should Have the key PathAttr "module"
    And the map should Have the key ModuleCall "beep"
    And the map should Not Have the key ForEachAttr "key"
    When Keys() is called to get a key set snapshot (Snapshot1)
    Then Snapshot1 should Have the key InputVariable "name"
    And Snapshot1 should Have the key LocalValue "hello"
    And Snapshot1 should Have the key PathAttr "module"
    And Snapshot1 should Have the key ModuleCall "beep"
    And Snapshot1 should Not Have the key ForEachAttr "key"
    When Get(InputVariable "name") is called, the value should be "Aisling"
    When Get(LocalValue "hello") is called, the value should be "hello"
    When Get(PathAttr "module") is called, the value should be "boop"
    When Get(ModuleCall "beep") is called, the value should be "unrealistic"
    When Get(ForEachAttr "key") is called, the value should be "" (zero value for string)
    When GetOk(InputVariable "name") is called, the value should be "Aisling" and ok should be true
    When GetOk(ForEachAttr "key") is called, the value should be "" and ok should be false
    When Remove(ModuleCall "beep") is called
    Then the map should Not Have the key ModuleCall "beep"
    And Snapshot1 should Still Have the key ModuleCall "beep" # Key set is a snapshot
    When Keys() is called again to get a new key set snapshot (Snapshot2)
    Then Snapshot2 should Not Have the key ModuleCall "beep"

  # Note: The `cty` aspects are indirect. The keys are `addrs` types, which
  # themselves might wrap or interact with `cty` (e.g., InstanceKey for resource addresses).
  # This BDD focuses on the map's API using these address types as keys.
  # Step definitions will need to:
  # - Create instances of addrs.InputVariable, addrs.LocalValue, etc.
  # - Interact with the addrs.Map[string] instance.
  # - Handle addrs.Set[Referenceable] for key sets.
  # - Distinguish between Get (returns zero value if not found) and GetOk (returns bool for presence).
