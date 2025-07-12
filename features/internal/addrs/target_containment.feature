# Metadata:
# Covers: internal/addrs/target_test.go
# TestFunctions:
# - TestTargetContains

Feature: Target Address Containment Logic
  This feature describes how Terraform determines if one addressable item
  (like a module, resource, or specific instance) is contained within or
  matched by a target address. This is key for CLI targeting functionality.

  Scenario Outline: Checking if a Target Address Contains Another Addressable Item
    Given a target address defined as "<TargetAddrString>" of type "<TargetType>"
    And another addressable item defined as "<OtherAddrString>" of type "<OtherType>"
    When I check if the target address contains the other addressable item
    Then the result should be <ContainsResult>

    Examples:
      # Module to Module
      | TargetAddrString | TargetType     | OtherAddrString            | OtherType      | ContainsResult | Description                                      |
      | module.foo       | ModuleInstance | module.bar                 | ModuleInstance | false          | Different modules                                |
      | module.foo       | ModuleInstance | module.foo                 | ModuleInstance | true           | Same module                                      |
      | (RootModule)     | ModuleInstance | module.foo                 | ModuleInstance | true           | Root contains any module                         |
      | module.foo       | ModuleInstance | (RootModule)               | ModuleInstance | false          | Child cannot contain root                        |
      | module.foo       | ModuleInstance | module.foo.module.bar[0]   | ModuleInstance | true           | Module contains child instance                   |
      | module.foo[2]    | ModuleInstance | module.foo[2].module.bar[0]| ModuleInstance | true           | Specific module instance contains child instance |
      # Module to Resource/Instance
      | module.foo       | ModuleInstance | module.foo.test_resource.bar   | AbsResource    | true           | Module contains resource in it                   |
      | module.foo       | ModuleInstance | module.foo.test_resource.bar[0]| AbsResourceInstance | true        | Module contains resource instance in it          |
      # Resource to Resource Instance
      | test_resource.foo | AbsResource    | test_resource.foo["bar"]   | AbsResourceInstance | true        | Resource contains its instance                   |
      | test_resource.foo["bar"] | AbsResourceInstance | test_resource.foo["bar"] | AbsResourceInstance | true     | Instance contains itself                         |
      | test_resource.foo | AbsResource    | module.bar.test_resource.foo[2] | AbsResourceInstance | false   | Resource in root vs instance in module         |
      | module.bar.test_resource.foo | AbsResource | module.bar.test_resource.foo[2] | AbsResourceInstance | true | Resource in module contains its instance       |
      | module.bar.test_resource.foo | AbsResource | module.bar[0].test_resource.foo[2] | AbsResourceInstance | false | Resource in module vs instance in specific module instance |
      # ConfigResource interactions
      | module.bar.test_resource.foo | ConfigResource | module.bar.test_resource.foo[2] | AbsResourceInstance | true        | ConfigResource contains instance in same module  |
      | module.bar                   | ModuleInstance | module.bar.test_resource.foo    | ConfigResource | true        | ModuleInstance contains ConfigResource in it     |
      | test_resource.foo            | ConfigResource | module.bar.test_resource.foo[2] | AbsResourceInstance | false       | ConfigResource in root vs instance in module   |
      | module.bar.test_resource.foo | AbsResource    | module.bar.test_resource.foo    | ConfigResource | true        | AbsResource matches ConfigResource               |
      # Module (config path) interactions
      | module.bar                   | Module (Config) | module.bar.module.baz        | Module (Config) | true        | Module path contains sub-module path             |
      | module.bar                   | Module (Config) | module.bar[0]                | ModuleInstance  | true        | Module path contains instance of itself          |
      | module.bar                   | ModuleInstance  | module.bar                   | Module (Config) | true        | Module instance matches its config path          |
      | module.bar[0]                | ModuleInstance  | module.bar                   | Module (Config) | false       | Specific instance cannot contain general path    |
      | module.bar.module.baz        | Module (Config) | module.bar[0].module.baz.test_resource.foo[1] | AbsResourceInstance | true | Deeply nested containment |
      | module.bar[0].module.baz     | ModuleInstance  | module.bar.module.baz        | Module (Config) | false       | Specific instance cannot contain general path    |

```

Notes for this Gherkin:

*   For `<TargetAddrString>` and `<OtherAddrString>`, `(RootModule)` is used to represent `RootModuleInstance` when it's the target subject.
*   The `<TargetType>` and `<OtherType>` columns are crucial to specify how the string should be interpreted (e.g., as a `ModuleInstance` target, an `AbsResource` target, a `ConfigResource`, or a `Module` config path). The step definitions will use the appropriate parsing or construction logic based on this type.
*   The examples try to cover the different kinds of containment relationships tested in `TestTargetContains`:
    *   Module-to-module (identity, parent-child).
    *   Module-to-resource/instance (resource defined within a module).
    *   Resource-to-instance (resource collection vs. specific instance).
    *   Interactions with `ConfigResource` and `Module` (configuration path) types.
*   This BDD focuses on the *logic* of containment rather than the parsing of the target strings themselves (which is covered by `parse_target.feature`).

The last test file in `internal/addrs/` appears to be `variable_test.go`.
