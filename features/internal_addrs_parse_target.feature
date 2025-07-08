# Source Go File: internal/addrs/parse_target.go
# Source Go Test: internal/addrs/parse_target_test.go

Feature: Parsing HCL Traversal to Target Address
  This feature describes how HCL traversals are parsed into Target (addrs.Target)
  objects. A Target can represent a module instance, a resource, or a specific
  resource instance, and is used for operations like `terraform plan -target=...`.

  Background:
    Given the Terraform addressing system for targets

  Scenario Outline: Parsing valid HCL traversals to Targets
    Given an HCL traversal string "<TraversalString>"
    When ParseTarget is called with the parsed traversal
    Then the resulting Target's Subject should be of type <ExpectedSubjectType>
    And its string representation (of the subject) should be "<EffectiveAddrString>"
    And no parsing error should occur

    Examples:
      | TraversalString                                          | ExpectedSubjectType   | EffectiveAddrString                                      |
      | module.foo                                               | ModuleInstance        | module.foo                                               |
      | module.foo[2]                                            | ModuleInstance        | module.foo[2]                                            |
      | module.foo[2].module.bar                                 | ModuleInstance        | module.foo[2].module.bar                                 |
      | aws_instance.foo                                         | AbsResource           | aws_instance.foo                                         |
      | resource.aws_instance.foo                                | AbsResource           | aws_instance.foo                                         |
      | aws_instance.foo[1]                                      | AbsResourceInstance   | aws_instance.foo[1]                                      |
      | data.aws_instance.foo                                    | AbsResource           | data.aws_instance.foo                                    |
      | data.aws_instance.foo[1]                                 | AbsResourceInstance   | data.aws_instance.foo[1]                                 |
      | ephemeral.aws_instance.foo                               | AbsResource           | ephemeral.aws_instance.foo                               |
      | ephemeral.aws_instance.foo[1]                            | AbsResourceInstance   | ephemeral.aws_instance.foo[1]                            |
      | module.foo.aws_instance.bar                              | AbsResource           | module.foo.aws_instance.bar                              |
      | module.foo.module.bar.aws_instance.baz                   | AbsResource           | module.foo.module.bar.aws_instance.baz                   |
      | module.foo.module.bar.aws_instance.baz["hello"]          | AbsResourceInstance   | module.foo.module.bar.aws_instance.baz["hello"]          |
      | module.foo.module.bar[0].data.aws_instance.baz           | AbsResource           | module.foo.module.bar[0].data.aws_instance.baz           |
      | module.foo.module.bar["a"].data.aws_instance.baz["hello"]| AbsResourceInstance   | module.foo.module.bar["a"].data.aws_instance.baz["hello"]|

  Scenario Outline: Parsing invalid HCL traversals for Targets
    Given an HCL traversal string "<TraversalString>"
    When ParseTarget is called with the parsed traversal
    Then an error should occur with a detail message containing "<ExpectedErrorMessageSubstring>"

    Examples:
      | TraversalString             | ExpectedErrorMessageSubstring                                           |
      | aws_instance                | Resource specification must include a resource type and name.           |
      | module                      | Prefix "module." must be followed by a module name.                     |
      | module.baz.bar              | Resource specification must include a resource type and name.           | # If "bar" is not a resource type
      | aws_instance.foo.bar        | Resource instance key must be given in square brackets.                 | # "bar" is not a valid key format here
      | aws_instance.foo[1].baz     | Unexpected extra operators after address.                               |
      | each.key                    | The keyword "each" is reserved and cannot be used to target a resource. |
      | count.index                 | The keyword "count" is reserved and cannot be used to target a resource.|
      | local.value                 | The keyword "local" is reserved and cannot be used to target a resource.|
      | path.root                   | The keyword "path" is reserved and cannot be used to target a resource. |
      | self.id                     | The keyword "self" is reserved and cannot be used to target a resource. |
      | terraform.planning          | The keyword "terraform" is reserved                                     |
      | var.foo                     | The keyword "var" is reserved                                           |
      | template                    | The keyword "template" is reserved                                      |

  # Note:
  # - ExpectedSubjectType refers to the Go type of the `Subject` field in `addrs.Target` (e.g., addrs.ModuleInstance, addrs.AbsResource, addrs.AbsResourceInstance).
  # - EffectiveAddrString is the string representation of the parsed subject.
  # - InstanceKeys (like IntKey, StringKey) are part of AbsResourceInstance and ModuleInstance subjects.
  # - The cty aspects are primarily how InstanceKey (which can wrap cty.Value) is parsed and stored within these address types.
  # - Step definitions will need to parse traversal strings into hcl.Traversal and then call ParseTarget.
  # - SourceRange in the Target object should cover the input HCL traversal string.
  # - Reserved keywords (count, each, local, var, path, self, terraform, template, lazy, arg) cannot be used as the first segment unless prefixed by "resource." if they are also resource type names.

  Scenario Outline: Checking if a Targetable address contains another Targetable address
    Given a targetable address A parsed from "<AddressAString>" (type <TypeA>)
    And another targetable address B parsed from "<AddressBString>" (type <TypeB>)
    When A's TargetContains method is called with B
    Then the result should be <ExpectedToContain>

    Examples:
      | AddressAString                             | TypeA                 | AddressBString                               | TypeB                 | ExpectedToContain |
      | module.foo                                 | ModuleInstance        | module.bar                                   | ModuleInstance        | false             |
      | module.foo                                 | ModuleInstance        | module.foo                                   | ModuleInstance        | true              |
      | ""                                         | RootModuleInstance    | module.foo                                   | ModuleInstance        | true              | # Root contains any module
      | module.foo                                 | ModuleInstance        | ""                                           | RootModuleInstance    | false             |
      | module.foo                                 | ModuleInstance        | module.foo.module.bar[0]                     | ModuleInstance        | true              |
      | module.foo[2]                              | ModuleInstance        | module.foo[2].module.bar[0]                  | ModuleInstance        | true              |
      | module.foo                                 | ModuleInstance        | module.foo.test_resource.bar                 | AbsResource           | true              |
      | module.foo                                 | ModuleInstance        | module.foo.test_resource.bar[0]              | AbsResourceInstance   | true              |
      | test_resource.foo                          | AbsResource           | test_resource.foo["bar"]                     | AbsResourceInstance   | true              |
      | test_resource.foo["bar"]                   | AbsResourceInstance   | test_resource.foo["bar"]                     | AbsResourceInstance   | true              |
      | test_resource.foo                          | AbsResource           | test_resource.foo[2]                         | AbsResourceInstance   | true              |
      | test_resource.foo                          | AbsResource           | module.bar.test_resource.foo[2]              | AbsResourceInstance   | false             | # Different module
      | module.bar.test_resource.foo               | AbsResource           | module.bar.test_resource.foo[2]              | AbsResourceInstance   | true              |
      | module.bar                                 | ModuleInstance        | module.bar:test_resource.foo                 | ConfigResource        | true              | # ConfigResource in ModuleInstance
      | module.bar.test_resource.foo               | AbsResource           | module.bar:test_resource.foo                 | ConfigResource        | true              | # ConfigResource for AbsResource
      | module.bar:test_resource.foo               | ConfigResource        | module.bar.test_resource.foo[2]              | AbsResourceInstance   | true              |
      | ""                                         | RootModule            | module.bar:test_resource.foo                 | ConfigResource        | true              | # ConfigResource in RootModule
      | module.bar                                 | Module                | module.bar.module.baz                        | Module                | true              | # Module containing Module
      | module.bar                                 | Module                | module.bar[0]                                | ModuleInstance        | true              | # Module containing ModuleInstance
      | module.bar[0]                              | ModuleInstance        | module.bar                                   | Module                | false             | # Specific instance cannot contain general module
      | module.bar.module.baz                      | Module                | module.bar[0].module.baz.test_resource.foo[1]| AbsResourceInstance   | true              |

  # Note for TargetContains:
  # - Step definitions need to parse AddressAString and AddressBString into their respective Targetable types.
  # - This might involve ParseTargetStr for most, but also direct construction for Module or ConfigResource.
  # - RootModuleInstance is addrs.RootModuleInstance.
  # - The `TypeA` and `TypeB` columns help guide the step definition on what type to expect/create.
