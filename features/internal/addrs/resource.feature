# Metadata:
# Covers: internal/addrs/resource_test.go
# TestFunctions:
# - TestResourceEqual_true
# - TestResourceEqual_false
# - TestResourceInstanceEqual_true
# - TestResourceInstanceEqual_false
# - TestAbsResourceInstanceEqual_true
# - TestAbsResourceInstanceEqual_false
# - TestAbsResourceUniqueKey
# - TestConfigResourceEqual_true
# - TestConfigResourceEqual_false

Feature: Resource Address Equality and Uniqueness
  This feature describes the behavior of equality checks and unique key generation
  for various resource address types in Terraform, including resource collections,
  specific instances, and configuration-level resource addresses.

  Scenario Outline: Resource Self-Equality
    Given a resource with mode "<Mode>", type "<Type>", and name "<Name>"
    When I compare it with itself
    Then the resources should be equal

    Examples:
      | Mode    | Type | Name |
      | Managed | a    | b    |
      | Data    | a    | b    |

  Scenario Outline: Resource Comparison
    Given a resource "R1" with mode "<Mode1>", type "<Type1>", and name "<Name1>"
    And a resource "R2" with mode "<Mode2>", type "<Type2>", and name "<Name2>"
    When I compare resource "R1" with resource "R2"
    Then they should <EqualityResult>

    Examples:
      | Mode1   | Type1 | Name1 | Mode2   | Type2 | Name2 | EqualityResult | Description              |
      | Data    | a     | b     | Managed | a     | b     | NOT be equal   | Different modes          |
      | Managed | a     | b     | Managed | b     | b     | NOT be equal   | Different types          |
      | Managed | a     | b     | Managed | a     | c     | NOT be equal   | Different names          |
      | Managed | a     | b     | Managed | a     | b     | be equal       | Identical                |

  Scenario Outline: Resource Instance Self-Equality
    Given a resource instance with mode "<Mode>", type "<Type>", name "<Name>", and key "<Key>"
    When I compare it with itself
    Then the resource instances should be equal

    Examples:
      | Mode    | Type | Name | Key         |
      | Managed | a    | b    | IntKey:0    |
      | Data    | a    | b    | StringKey:x |

  Scenario Outline: Resource Instance Comparison
    Given a resource instance "RI1" with mode "<Mode1>", type "<Type1>", name "<Name1>", and key "<Key1>"
    And a resource instance "RI2" with mode "<Mode2>", type "<Type2>", name "<Name2>", and key "<Key2>"
    When I compare resource instance "RI1" with resource instance "RI2"
    Then they should <EqualityResult>

    Examples:
      | Mode1   | Type1 | Name1 | Key1     | Mode2   | Type2 | Name2 | Key2     | EqualityResult | Description              |
      | Data    | a     | b     | IntKey:0 | Managed | a     | b     | IntKey:0 | NOT be equal   | Different modes          |
      | Managed | a     | b     | IntKey:0 | Managed | b     | b     | IntKey:0 | NOT be equal   | Different types          |
      | Managed | a     | b     | IntKey:0 | Managed | a     | c     | IntKey:0 | NOT be equal   | Different names          |
      | Data    | a     | b     | IntKey:0 | Data    | a     | b     | StringKey:0| NOT be equal   | Different key types      |
      | Data    | a     | b     | IntKey:0 | Data    | a     | b     | IntKey:0   | be equal       | Identical                |

  Scenario Outline: Absolute Resource Instance Self-Equality
    Given an absolute resource instance in module "<ModuleAddr>" with mode "<Mode>", type "<Type>", name "<Name>", and key "<Key>"
    When I compare it with itself
    Then the absolute resource instances should be equal

    Examples:
      | ModuleAddr               | Mode    | Type | Name | Key         |
      | module.foo               | Managed | a    | b    | IntKey:0    |
      | module.foo               | Data    | a    | b    | IntKey:0    |
      | module.foo[1].module.bar | Managed | a    | b    | StringKey:a |

  Scenario Outline: Absolute Resource Instance Comparison
    Given an absolute resource instance "ARI1" in module "<Module1Addr>" with mode "<Mode1>", type "<Type1>", name "<Name1>", and key "<Key1>"
    And an absolute resource instance "ARI2" in module "<Module2Addr>" with mode "<Mode2>", type "<Type2>", name "<Name2>", and key "<Key2>"
    When I compare absolute resource instance "ARI1" with "ARI2"
    Then they should <EqualityResult>

    Examples:
      | Module1Addr | Mode1   | Type1 | Name1 | Key1     | Module2Addr            | Mode2   | Type2 | Name2 | Key2     | EqualityResult | Description                  |
      | module.foo  | Managed | a     | b     | IntKey:0 | module.foo             | Data    | a     | b     | IntKey:0 | NOT be equal   | Different modes              |
      | module.foo  | Managed | a     | b     | IntKey:0 | module.foo[1].module.bar | Managed | a     | b     | IntKey:0 | NOT be equal   | Different modules            |
      | module.foo  | Managed | a     | b     | IntKey:0 | module.foo             | Managed | a     | b     | StringKey:0| NOT be equal   | Different key types          |
      | module.foo  | Managed | a     | b     | IntKey:0 | module.foo             | Managed | a     | b     | IntKey:0 | be equal       | Identical                    |

  Scenario Outline: Absolute Resource Unique Key Comparison
    Given an absolute resource "AR" in module "<ModuleAddr>" with mode "<Mode>" type "<Type>" and name "<Name>"
    And <OtherType> "Other" defined as <OtherDefinition>
    When I compare the unique key of "AR" with the unique key of "Other"
    Then the unique keys should <MatchOrNot>

    Examples:
      | Mode    | Type | Name        | ModuleAddr         | OtherType              | OtherDefinition                                         | MatchOrNot    |
      | Managed | a    | b1          | (RootModule)       | same AbsResource       |                                                         | be equal      |
      | Managed | a    | b1          | (RootModule)       | different AbsResource  | mode Managed, type "a", name "b2" in module (RootModule)  | NOT be equal  |
      | Managed | a    | b1          | (RootModule)       | different AbsResource  | mode Managed, type "a", name "in_module" in module "module.boop" | NOT be equal  |
      | Managed | a    | in_module   | module.boop        | same AbsResource       |                                                         | be equal      |
      | Managed | a    | b1          | (RootModule)       | AbsResourceInstance    | of AR with key NoKey                                    | NOT be equal  |
      | Managed | a    | b1          | (RootModule)       | AbsResourceInstance    | of AR with key IntKey:1                                 | NOT be equal  |

  Scenario Outline: Config Resource Self-Equality
    Given a config resource in module "<ModulePath>" with mode "<Mode>", type "<Type>", and name "<Name>"
    When I compare it with itself
    Then the config resources should be equal

    Examples:
      | ModulePath   | Mode    | Type | Name |
      | (RootModule) | Managed | a    | b    |
      | (RootModule) | Data    | a    | b    |
      | module.foo   | Managed | a    | b    |
      | module.foo   | Data    | a    | b    |

  Scenario Outline: Config Resource Comparison
    Given a config resource "CR1" in module "<Module1Path>" with mode "<Mode1>", type "<Type1>", and name "<Name1>"
    And a config resource "CR2" in module "<Module2Path>" with mode "<Mode2>", type "<Type2>", and name "<Name2>"
    When I compare config resource "CR1" with "CR2"
    Then they should <EqualityResult>

    Examples:
      | Module1Path | Mode1   | Type1 | Name1 | Module2Path | Mode2   | Type2 | Name2 | EqualityResult | Description          |
      | module.foo  | Managed | a     | b     | module.foo  | Data    | a     | b     | NOT be equal   | Different modes      |
      | module.foo  | Managed | a     | b     | module.foobar | Managed | a     | b     | NOT be equal   | Different modules    |
      | module.foo  | Managed | a     | b     | module.foo  | Managed | x     | b     | NOT be equal   | Different types      |
      | module.foo  | Managed | a     | b     | module.foo  | Managed | a     | x     | NOT be equal   | Different names      |
      | module.foo  | Managed | a     | b     | module.foo  | Managed | a     | b     | be equal       | Identical            |

```

Notes for this Gherkin:
*   `(RootModule)` is used for clarity to represent `RootModuleInstance` or `RootModule` where appropriate.
*   Keys like `IntKey:0` and `StringKey:x` are used to make the Gherkin readable.
*   The `AbsResourceUniqueKey` scenario is designed to handle comparisons between an `AbsResource` and itself, another `AbsResource`, or an `AbsResourceInstance` derived from it, reflecting the Go test structure.
*   The scenarios cover self-equality and comparisons based on differing components (mode, type, name, key, module path) for each relevant address type.

The next file is `internal/addrs/resource_type_test.go`.
