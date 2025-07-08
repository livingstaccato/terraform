# Source Go File: internal/addrs/action.go
# Source Go Test: internal/addrs/action_test.go

Feature: Terraform Action Addressing and Equality
  This feature describes how Terraform actions (general actions, action instances,
  absolute action instances, and config actions) are represented, stringified,
  and compared for equality. It also covers the UniqueKey generation for
  absolute actions.

  Background:
    Given the Terraform addressing system for actions

  Scenario Outline: Action equality
    Given an Action A with Type "<TypeA>" and Name "<NameA>"
    And an Action B with Type "<TypeB>" and Name "<NameB>"
    When Action A is compared with Action B using Equal()
    Then the result should be <IsEqual>

    Examples:
      | TypeA | NameA | TypeB | NameB | IsEqual |
      | "foo" | "bar" | "foo" | "bar" | true    |
      | "foo" | "bar" | "the" | "bloop" | false   |
      | "a"   | "b"   | "b"   | "b"   | false   | # Different Type
      | "a"   | "b"   | "a"   | "c"   | false   | # Different Name

  Scenario Outline: ActionInstance equality
    Given an ActionInstance A with Action Type "<ActionTypeA>", Name "<ActionNameA>", and Key <KeyA>
    And an ActionInstance B with Action Type "<ActionTypeB>", Name "<ActionNameB>", and Key <KeyB>
    When ActionInstance A is compared with ActionInstance B using Equal()
    Then the result should be <IsEqual>

    Examples:
      # KeyA and KeyB can be "NoKey", "IntKey(0)", "StringKey(\"s\")"
      | ActionTypeA | ActionNameA | KeyA            | ActionTypeB | ActionNameB | KeyB            | IsEqual |
      | "foo"       | "bar"       | NoKey           | "foo"       | "bar"       | NoKey           | true    |
      | "foo"       | "bar"       | NoKey           | "foo"       | "bar"       | IntKey(1)       | false   | # Different Key
      | "foo"       | "bar"       | NoKey           | "baz"       | "bat"       | IntKey(1)       | false   | # Different Action
      | "the"       | "bloop"     | StringKey("fish") | "the"       | "bloop"     | StringKey("fish") | true    |

  Scenario Outline: AbsActionInstance equality
    Given an AbsActionInstance A with ModulePath "<ModulePathA>", Action Type "<ActionTypeA>", Name "<ActionNameA>", and Key <KeyA>
    And an AbsActionInstance B with ModulePath "<ModulePathB>", Action Type "<ActionTypeB>", Name "<ActionNameB>", and Key <KeyB>
    When AbsActionInstance A is compared with AbsActionInstance B using Equal()
    Then the result should be <IsEqual>

    Examples:
      | ModulePathA  | ActionTypeA | ActionNameA | KeyA      | ModulePathB  | ActionTypeB | ActionNameB | KeyB      | IsEqual |
      | ""           | "foo"       | "bar"       | NoKey     | ""           | "foo"       | "bar"       | NoKey     | true    |
      | ""           | "foo"       | "bar"       | NoKey     | ""           | "foo"       | "bar"       | IntKey(1) | false   | # Different Key
      | ""           | "foo"       | "bar"       | NoKey     | "module.child[1]" | "foo"    | "bar"       | NoKey     | false   | # Different ModulePath
      | "module.ch"  | "the"       | "bloop"     | StringKey("fish") | "module.ch"  | "the"    | "bloop"     | StringKey("fish") | true    |

  Scenario Outline: ConfigAction equality
    Given a ConfigAction A with ModulePath "<ModulePathA>", Action Type "<ActionTypeA>", and Name "<ActionNameA>"
    And a ConfigAction B with ModulePath "<ModulePathB>", Action Type "<ActionTypeB>", and Name "<ActionNameB>"
    When ConfigAction A is compared with ConfigAction B using Equal()
    Then the result should be <IsEqual>

    Examples:
      | ModulePathA | ActionTypeA | ActionNameA | ModulePathB | ActionTypeB | ActionNameB | IsEqual |
      | ""          | "foo"       | "bar"       | ""          | "foo"       | "bar"       | true    |
      | ""          | "foo"       | "bar"       | ""          | "foo"       | "baz"       | false   | # Different Name
      | ""          | "foo"       | "bar"       | ""          | "baz"       | "bar"       | false   | # Different Type
      | ""          | "foo"       | "bar"       | "module.mod"| "foo"       | "bar"       | false   | # Different ModulePath

  Scenario Outline: AbsAction UniqueKey comparison
    Given an AbsAction A defined as Action Type "<ActionTypeA>" Name "<ActionNameA>" in ModulePath "<ModulePathA>"
    And a UniqueKeyer B, which is <DescriptionB>
      # DescriptionB could be "the same AbsAction", "a different AbsAction (Type '<TypeB>' Name '<NameB>' in Module '<ModulePathB>')",
      # "an AbsActionInstance derived from A with Key <KeyB>", etc.
    When A.UniqueKey() is compared with B.UniqueKey()
    Then the keys should be <ShouldBeEqual>

    Examples:
      | ActionTypeA | ActionNameA | ModulePathA    | DescriptionB                                                              | ShouldBeEqual |
      | "a"         | "b1"        | ""             | the same AbsAction                                                        | true          |
      | "a"         | "b1"        | ""             | a different AbsAction (Type "a" Name "b2" in Module "")                 | false         |
      | "a"         | "b1"        | ""             | a different AbsAction (Type "a" Name "in_module" in Module "module.boop") | false         |
      | "a"         | "b1"        | ""             | an AbsActionInstance derived from A with Key NoKey                        | false         | # NoKey instance is distinct from its resource
      | "a"         | "b1"        | ""             | an AbsActionInstance derived from A with Key IntKey(1)                    | false         |

  # Helper step definitions will be needed to:
  # - Parse string representations of ModulePath (e.g., "" for root, "module.child") into addrs.ModuleInstance or addrs.Module.
  # - Parse string representations of InstanceKey (e.g., "NoKey", "IntKey(0)", "StringKey(\"s\")") into addrs.InstanceKey.
  # - Construct Action, ActionInstance, AbsActionInstance, and ConfigAction objects.
  # - For UniqueKeyer B, construct the appropriate address type based on DescriptionB.
  # - The `mustParseModuleInstanceStr` helper from tests might be useful for step defs.
  # - Note: The `cty` aspects are primarily in how InstanceKey (which can be a cty.Value wrapper) affects equality and string representation,
  #   although Action itself does not directly embed cty.Values, its instances do via InstanceKey.
  # - String() methods for these types are also implicitly tested by their usage in test run names.
