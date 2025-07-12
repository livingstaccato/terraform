# Metadata:
# Covers: internal/addrs/module_instance_test.go
# TestFunctions:
# - TestModuleInstanceEqual_true
# - TestModuleInstanceEqual_false
# - TestModuleInstance_IsDeclaredByCall
# - TestModuleInstance_ContainingModule
# Note: Benchmark tests (BenchmarkStringShort, BenchmarkStringLong) are not typically covered by BDD.

Feature: Module Instance Addressing
  This feature describes how module instances are addressed and how these addresses
  are compared and manipulated. Module instance addresses are fundamental for
  identifying specific instantiations of modules, especially when using count or for_each.

  Scenario Outline: Module Instance Equality - Self Comparison
    Given a module instance address string "<AddrStr>"
    When I parse it into a ModuleInstance "MI"
    And I compare ModuleInstance "MI" with itself
    Then they should be equal

    Examples:
      | AddrStr                                  |
      | module.foo                               |
      | module.foo.module.bar                    |
      | module.foo[1].module.bar                 |
      | module.foo["a"].module.bar["b"]          |
      | module.foo["a"].module.bar.module.baz[3] |

  Scenario Outline: Module Instance Equality - Cross Comparison
    Given a module instance address string "<LeftAddrStr>"
    And another module instance address string "<RightAddrStr>"
    When I parse "<LeftAddrStr>" into a ModuleInstance "LeftMI"
    And I parse "<RightAddrStr>" into a ModuleInstance "RightMI"
    And I compare ModuleInstance "LeftMI" with ModuleInstance "RightMI"
    Then they should <EqualityResult>

    Examples:
      | LeftAddrStr               | RightAddrStr            | EqualityResult |
      | module.foo                | module.bar              | NOT be equal   |
      | module.foo                | module.foo.module.bar   | NOT be equal   |
      | module.foo[1]             | module.bar[1]           | NOT be equal   |
      | module.foo[1]             | module.foo["1"]         | NOT be equal   | # Integer key vs String key
      | module.foo.module.bar     | module.foo[1].module.bar| NOT be equal   |
      | module.foo.module.bar     | module.foo["a"].module.bar| NOT be equal   |

  Scenario Outline: Checking if a Module Instance is Declared by a Specific Module Call
    Given a module instance with address "<InstanceAddrStr>"
    And an absolute module call with name "<CallName>" in module instance "<CallModulePathStr>"
    When I check if the module instance is declared by this absolute module call
    Then the result should be <IsDeclared>

    Examples:
      | InstanceAddrStr    | CallModulePathStr          | CallName | IsDeclared |
      | module.child       |                            | child    | true       | # Root calling child
      | module.child       | module.kinder              | child    | false      | # kinder.child is not instance of kinder's call to child
      | module.kinder      | module.kinder              | child    | false      | # kinder is not instance of kinder's call to child
      | module.child       | module.kinder["a"]         | kinder   | false      |
      # Edge cases from test
      |                    |                            |          | false      | # Empty instance, empty call
      | module.child       |                            |          | false      | # Instance, empty call
      |                    |                            | child    | false      | # Empty instance, call in root

  Scenario Outline: Determining the Containing Module Configuration Address
    Given a module instance with address "<InstanceAddrStr>"
    When I request its containing module configuration address
    Then the resulting address string should be "<ExpectedContainingAddrStr>"

    Examples:
      | InstanceAddrStr                    | ExpectedContainingAddrStr    | Description                  |
      | module.parent.module.child       | module.parent.module.child   | No specific instance key     |
      | module.parent.module.child[0]    | module.parent.module.child   | Last step has instance key   |
      | module.parent[0].module.child    | module.parent[0].module.child| Middle step has instance key |
      | module.parent[0].module.child[0] | module.parent[0].module.child| All steps have instance keys |
      | module.parent                    | module.parent                | Single module, no key        |
      | module.parent[0]                 | module.parent                | Single module, with key      |

```

Notes on this Gherkin:

*   The benchmark tests are noted as not covered, which is standard for BDD.
*   For `IsDeclaredByCall`, `<CallModulePathStr>` being empty implies `RootModuleInstance`.
*   The examples aim to cover the different conditions tested in the Go file, including edge cases for `IsDeclaredByCall`.
*   The `mustParseModuleInstanceStr` helper in the Go test simplifies parsing; the Gherkin assumes successful parsing for valid inputs as per the test structure. Error handling for parsing itself would be a different feature (likely related to `ParseModuleInstanceStr` if it had more complex validation tests).

Next up is `internal/addrs/module_test.go`.
