# Metadata:
# Covers: internal/addrs/action_test.go
# TestFunctions:
# - TestActionEqual
# - TestActionInstanceEqual
# - TestAbsActionInstanceEqual
# - TestConfigActionEqual
# - TestAbsActionUniqueKey

Feature: Action Address Equality and Uniqueness
  This feature describes the behavior of equality checks and unique key generation
  for various action address types within Terraform. These addresses are crucial
  for identifying and differentiating actions performed on resources and modules.

  Scenario: Action Equality
    Given an Action with Type "foo" and Name "bar"
    When I compare it with itself
    Then the Actions should be equal

    Given an Action "A1" with Type "foo" and Name "bar"
    And an Action "A2" with Type "foo" and Name "bar"
    When I compare Action "A1" with Action "A2"
    Then the Actions should be equal

    Given an Action "A1" with Type "a" and Name "b"
    And an Action "A2" with Type "b" and Name "b"
    When I compare Action "A1" with Action "A2"
    Then the Actions should NOT be equal

    Given an Action "A1" with Type "a" and Name "b"
    And an Action "A2" with Type "a" and Name "c"
    When I compare Action "A1" with Action "A2"
    Then the Actions should NOT be equal

  Scenario: Action Instance Equality
    Given an Action Instance "AI1" with Type "foo", Name "bar", and Key "NoKey"
    When I compare Action Instance "AI1" with itself
    Then the Action Instances should be equal

    Given an Action Instance "AI1" with Type "the", Name "bloop", and Key "StringKey:fish"
    When I compare Action Instance "AI1" with itself
    Then the Action Instances should be equal

    Given an Action Instance "AI1" with Type "foo", Name "bar", and Key "NoKey"
    And an Action Instance "AI2" with Type "foo", Name "bar", and Key "NoKey"
    When I compare Action Instance "AI1" with Action Instance "AI2"
    Then the Action Instances should be equal

    Given an Action Instance "AI1" with Type "foo", Name "bar", and Key "NoKey"
    And an Action Instance "AI2" with Type "foo", Name "bar", and Key "IntKey:1"
    When I compare Action Instance "AI1" with Action Instance "AI2"
    Then the Action Instances should NOT be equal

    Given an Action Instance "AI1" with Type "foo", Name "bar", and Key "NoKey"
    And an Action Instance "AI2" with Type "baz", Name "bat", and Key "IntKey:1" # Different Action part
    When I compare Action Instance "AI1" with Action Instance "AI2"
    Then the Action Instances should NOT be equal

  Scenario: Absolute Action Instance Equality
    Given an Absolute Action Instance "AAI1" in module "RootModuleInstance" with Type "foo", Name "bar", and Key "NoKey"
    When I compare Absolute Action Instance "AAI1" with itself
    Then the Absolute Action Instances should be equal

    Given an Absolute Action Instance "AAI1" in module "module.child" with Type "the", Name "bloop", and Key "StringKey:fish"
    When I compare Absolute Action Instance "AAI1" with itself
    Then the Absolute Action Instances should be equal

    Given an Absolute Action Instance "AAI1" in module "RootModuleInstance" with Type "foo", Name "bar", and Key "NoKey"
    And an Absolute Action Instance "AAI2" in module "RootModuleInstance" with Type "foo", Name "bar", and Key "NoKey"
    When I compare Absolute Action Instance "AAI1" with Absolute Action Instance "AAI2"
    Then the Absolute Action Instances should be equal

    Given an Absolute Action Instance "AAI1" in module "RootModuleInstance" with Type "foo", Name "bar", and Key "NoKey"
    And an Absolute Action Instance "AAI2" in module "RootModuleInstance" with Type "foo", Name "bar", and Key "IntKey:1"
    When I compare Absolute Action Instance "AAI1" with Absolute Action Instance "AAI2"
    Then the Absolute Action Instances should NOT be equal

    Given an Absolute Action Instance "AAI1" in module "RootModuleInstance" with Type "foo", Name "bar", and Key "NoKey"
    And an Absolute Action Instance "AAI2" in module "module.child[1]" with Type "foo", Name "bar", and Key "NoKey"
    When I compare Absolute Action Instance "AAI1" with Absolute Action Instance "AAI2"
    Then the Absolute Action Instances should NOT be equal

    Given an Absolute Action Instance "AAI1" in module "RootModuleInstance" with Type "oof", Name "rab", and Key "NoKey"
    And an Absolute Action Instance "AAI2" in module "module.foo" with Type "foo", Name "bar", and Key "IntKey:11"
    When I compare Absolute Action Instance "AAI1" with Absolute Action Instance "AAI2"
    Then the Absolute Action Instances should NOT be equal

  Scenario: Config Action Equality
    Given a Config Action "CA1" in module "RootModule" with Type "foo" and Name "bar"
    When I compare Config Action "CA1" with itself
    Then the Config Actions should be equal

    Given a Config Action "CA1" in module "child" with Type "the" and Name "bloop"
    When I compare Config Action "CA1" with itself
    Then the Config Actions should be equal

    Given a Config Action "CA1" in module "RootModule" with Type "foo" and Name "bar"
    And a Config Action "CA2" in module "RootModule" with Type "foo" and Name "bar"
    When I compare Config Action "CA1" with Config Action "CA2"
    Then the Config Actions should be equal

    Given a Config Action "CA1" in module "RootModule" with Type "foo" and Name "bar"
    And a Config Action "CA2" in module "RootModule" with Type "foo" and Name "baz" # Different Name
    When I compare Config Action "CA1" with Config Action "CA2"
    Then the Config Actions should NOT be equal

    Given a Config Action "CA1" in module "RootModule" with Type "foo" and Name "bar"
    And a Config Action "CA2" in module "RootModule" with Type "baz" and Name "bar" # Different Type
    When I compare Config Action "CA1" with Config Action "CA2"
    Then the Config Actions should NOT be equal

    Given a Config Action "CA1" in module "RootModule" with Type "foo" and Name "bar"
    And a Config Action "CA2" in module "mod" with Type "foo" and Name "bar" # Different Module
    When I compare Config Action "CA1" with Config Action "CA2"
    Then the Config Actions should NOT be equal

  Scenario Outline: Absolute Action Unique Key Comparison
    Given an Absolute Action "Receiver" of type "<ReceiverType>" with name "<ReceiverName>" in module "<ReceiverModule>"
    And a <OtherKind> "Other" of type "<OtherType>" with name "<OtherName>" in module "<OtherModule>" with instance key "<OtherInstanceKey>"
    When I compare the unique key of "Receiver" with the unique key of "Other"
    Then the unique keys should <MatchOrNot>

    Examples:
      | ReceiverType | ReceiverName | ReceiverModule     | OtherKind            | OtherType | OtherName   | OtherModule        | OtherInstanceKey | MatchOrNot    |
      | "a"          | "b1"         | "RootModuleInstance" | AbsoluteAction       | "a"       | "b1"        | "RootModuleInstance" | ""               | be equal      |
      | "a"          | "b1"         | "RootModuleInstance" | AbsoluteAction       | "a"       | "b2"        | "RootModuleInstance" | ""               | NOT be equal  |
      | "a"          | "b1"         | "RootModuleInstance" | AbsoluteAction       | "a"       | "in_module" | "module.boop"        | ""               | NOT be equal  |
      | "a"          | "in_module"  | "module.boop"        | AbsoluteAction       | "a"       | "in_module" | "module.boop"        | ""               | be equal      |
      | "a"          | "b1"         | "RootModuleInstance" | AbsActionInstance    | "a"       | "b1"        | "RootModuleInstance" | "NoKey"          | NOT be equal  |
      | "a"          | "b1"         | "RootModuleInstance" | AbsActionInstance    | "a"       | "b1"        | "RootModuleInstance" | "IntKey:1"       | NOT be equal  |

  Scenario Outline: Absolute Action Instance Unique Key Comparison (Self and with its Action)
    Given an Absolute Action Instance "AAI1" in module "<Module>" with Type "<Type>", Name "<Name>", and Key "<Key>"
    When I compare the unique key of "AAI1" with itself
    Then the unique keys should be equal

    # This scenario is implicitly covered by the TestAbsActionUniqueKey logic where an AbsAction is compared to its AbsActionInstance
    # For BDD, it's clearer to state it directly if needed, but the Go test structure is slightly different.
    # The example table above for "Absolute Action Unique Key Comparison" covers the cases from TestAbsActionUniqueKey.
    # If specific AbsActionInstance to AbsActionInstance comparisons (other than self) are needed, they can be added.
