# Source Go File: internal/addrs/resource.go
# Source Go Test: internal/addrs/resource_test.go

Feature: Resource Addressing and Equality
  This feature describes how Terraform resource addresses (Resource, ResourceInstance,
  AbsResourceInstance, ConfigResource) are represented, stringified (implicitly by test names),
  and compared for equality. It also covers UniqueKey generation for absolute resources.

  Background:
    Given the Terraform addressing system for resources

  Scenario Outline: Resource equality
    Given a Resource A with Mode <ModeA>, Type "<TypeA>", and Name "<NameA>"
    And a Resource B with Mode <ModeB>, Type "<TypeB>", and Name "<NameB>"
    When Resource A is compared with Resource B using Equal()
    Then the result should be <IsEqual>

    Examples:
      | ModeA               | TypeA | NameA | ModeB               | TypeB | NameB | IsEqual |
      | ManagedResourceMode | "a"   | "b"   | ManagedResourceMode | "a"   | "b"   | true    |
      | DataResourceMode    | "a"   | "b"   | DataResourceMode    | "a"   | "b"   | true    |
      | DataResourceMode    | "a"   | "b"   | ManagedResourceMode | "a"   | "b"   | false   | # Different Mode
      | ManagedResourceMode | "a"   | "b"   | ManagedResourceMode | "x"   | "b"   | false   | # Different Type
      | ManagedResourceMode | "a"   | "b"   | ManagedResourceMode | "a"   | "x"   | false   | # Different Name

  Scenario Outline: ResourceInstance equality
    Given a ResourceInstance A with Mode <ModeA>, Type "<TypeA>", Name "<NameA>", and Key <KeyA>
    And a ResourceInstance B with Mode <ModeB>, Type "<TypeB>", Name "<NameB>", and Key <KeyB>
    When ResourceInstance A is compared with ResourceInstance B using Equal()
    Then the result should be <IsEqual>
    # KeyA/KeyB can be "NoKey", "IntKey(0)", "StringKey(\"s\")"

    Examples:
      | ModeA               | TypeA | NameA | KeyA        | ModeB               | TypeB | NameB | KeyB        | IsEqual |
      | ManagedResourceMode | "a"   | "b"   | IntKey(0)   | ManagedResourceMode | "a"   | "b"   | IntKey(0)   | true    |
      | DataResourceMode    | "a"   | "b"   | StringKey("x") | DataResourceMode    | "a"   | "b"   | StringKey("x") | true    |
      | DataResourceMode    | "a"   | "b"   | IntKey(0)   | ManagedResourceMode | "a"   | "b"   | IntKey(0)   | false   | # Diff Mode
      | ManagedResourceMode | "a"   | "b"   | IntKey(0)   | ManagedResourceMode | "x"   | "b"   | IntKey(0)   | false   | # Diff Type
      | ManagedResourceMode | "a"   | "b"   | IntKey(0)   | ManagedResourceMode | "a"   | "x"   | IntKey(0)   | false   | # Diff Name
      | DataResourceMode    | "a"   | "b"   | IntKey(0)   | DataResourceMode    | "a"   | "b"   | StringKey("0") | false   | # Diff Key (type)

  Scenario Outline: AbsResourceInstance equality
    Given an AbsResourceInstance A with Module Path "<ModulePathA>", Mode <ModeA>, Type "<TypeA>", Name "<NameA>", and Key <KeyA>
    And an AbsResourceInstance B with Module Path "<ModulePathB>", Mode <ModeB>, Type "<TypeB>", Name "<NameB>", and Key <KeyB>
    When AbsResourceInstance A is compared with AbsResourceInstance B using Equal()
    Then the result should be <IsEqual>

    Examples:
      | ModulePathA               | ModeA               | TypeA | NameA | KeyA      | ModulePathB               | ModeB               | TypeB | NameA | KeyB      | IsEqual |
      | "module.foo"              | ManagedResourceMode | "a"   | "b"   | IntKey(0) | "module.foo"              | ManagedResourceMode | "a"   | "b"   | IntKey(0) | true    |
      | "module.foo[1].module.bar"| DataResourceMode    | "a"   | "b"   | StringKey("x")| "module.foo[1].module.bar"| DataResourceMode    | "a"   | "b"   | StringKey("x")| true    |
      | "module.foo"              | ManagedResourceMode | "a"   | "b"   | IntKey(0) | "module.foo"              | DataResourceMode    | "a"   | "b"   | IntKey(0) | false   | # Diff Mode
      | "module.foo"              | ManagedResourceMode | "a"   | "b"   | IntKey(0) | "module.foo[1].module.bar"| ManagedResourceMode | "a"   | "b"   | IntKey(0) | false   | # Diff ModulePath
      | "module.foo"              | ManagedResourceMode | "a"   | "b"   | IntKey(0) | "module.foo"              | ManagedResourceMode | "a"   | "b"   | StringKey("0")| false   | # Diff Key

  Scenario Outline: AbsResource UniqueKey comparison
    Given an AbsResource A defined with Mode <ModeA>, Type "<TypeA>", Name "<NameA>" in ModulePath "<ModulePathA>"
    And a UniqueKeyer B, which is <DescriptionB>
      # DescriptionB could be "the same AbsResource", "a different AbsResource (Type '<TypeB>' Name '<NameB>' in Module '<ModulePathB>')",
      # "an AbsResourceInstance derived from A with Key <KeyB>", etc.
    When A.UniqueKey() is compared with B.UniqueKey()
    Then the keys should be <ShouldBeEqual>

    Examples:
      | ModeA               | TypeA | NameA    | ModulePathA    | DescriptionB                                                              | ShouldBeEqual |
      | ManagedResourceMode | "a"   | "b1"     | ""             | the same AbsResource                                                        | true          |
      | ManagedResourceMode | "a"   | "b1"     | ""             | a different AbsResource (Mode ManagedResourceMode Type "a" Name "b2" in Module "") | false         |
      | ManagedResourceMode | "a"   | "b1"     | ""             | a different AbsResource (Mode ManagedResourceMode Type "a" Name "in_module" in Module "module.boop") | false         |
      | ManagedResourceMode | "a"   | "b1"     | ""             | an AbsResourceInstance derived from A with Key NoKey                        | false         | # NoKey instance is distinct from its resource
      | ManagedResourceMode | "a"   | "b1"     | ""             | an AbsResourceInstance derived from A with Key IntKey(1)                    | false         |

  Scenario Outline: ConfigResource equality
    Given a ConfigResource A with Module Path "<ModulePathA>", Mode <ModeA>, Type "<TypeA>", and Name "<NameA>"
    And a ConfigResource B with Module Path "<ModulePathB>", Mode <ModeB>, Type "<TypeB>", and Name "<NameB>"
    When ConfigResource A is compared with ConfigResource B using Equal()
    Then the result should be <IsEqual>

    Examples:
      | ModulePathA  | ModeA               | TypeA | NameA | ModulePathB  | ModeB               | TypeB | NameA | IsEqual |
      | ""           | ManagedResourceMode | "a"   | "b"   | ""           | ManagedResourceMode | "a"   | "b"   | true    |
      | "module.foo" | DataResourceMode    | "a"   | "b"   | "module.foo" | DataResourceMode    | "a"   | "b"   | true    |
      | "module.foo" | ManagedResourceMode | "a"   | "b"   | "module.foo" | DataResourceMode    | "a"   | "b"   | false   | # Diff Mode
      | "module.foo" | ManagedResourceMode | "a"   | "b"   | "module.bar" | ManagedResourceMode | "a"   | "b"   | false   | # Diff ModulePath

  # Note:
  # - Mode can be ManagedResourceMode or DataResourceMode.
  # - InstanceKey can be NoKey, IntKey(value), or StringKey(value).
  # - ModulePath for AbsResourceInstance is an addrs.ModuleInstance.
  # - ModulePath for ConfigResource is an addrs.Module.
  # - The cty aspects are primarily via InstanceKey which wraps cty.Value for string/number keys.
  # - Step definitions will need to parse string representations into the correct addrs types.
  # - String() methods are implicitly tested by their usage in test names/outputs.
