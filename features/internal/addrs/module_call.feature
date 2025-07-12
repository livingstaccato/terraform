# Metadata:
# Covers: internal/addrs/module_call_test.go
# TestFunctions:
# - TestAbsModuleCallOutput
# - TestAbsModuleCallOutput_ConfigOutputValue

Feature: Absolute Module Call Output Addressing
  This feature describes how output value addresses are derived from absolute module call addresses.
  This is important for referencing outputs of modules in Terraform configurations.

  Scenario Outline: Deriving Absolute Output Value Address from Absolute Module Call
    Given an absolute module call named "<CallName>" within the module instance path "<ModulePath>"
    When I request the absolute output value address for an output named "<OutputName>" from this module call
    Then the string representation of the derived absolute output value address should be "<ExpectedAddress>"

    Examples:
      | ModulePath         | CallName | OutputName | ExpectedAddress             | Description    |
      | ""                 | "hello"  | "foo"      | module.hello.foo            | Simple case    |
      | "module.child"     | "hello"  | "foo"      | module.child.module.hello.foo | Nested case    |

  Scenario Outline: Deriving Config Output Value Address from Absolute Module Call's Output
    Given an absolute module call named "<CallName>" within the module instance path "<ModulePath>"
    When I request the absolute output value address for an output named "<OutputName>" from this module call
    And I convert this absolute output value address to a config output value address
    Then the string representation of the derived config output value address should be "<ExpectedAddress>"

    Examples:
      | ModulePath         | CallName | OutputName | ExpectedAddress                   | Description    |
      | ""                 | "hello"  | "foo"      | module.hello.output.foo           | Simple case    |
      | "module.child"     | "hello"  | "foo"      | module.child.module.hello.output.foo | Nested case    |

```

Notes on this Gherkin:

*   I've used `<ModulePath>` to represent the `Module` field of `AbsModuleCall`. An empty string signifies the root module context (`ModuleInstance{}`), and "module.child" represents a nested module instance. The step definition would need to parse this into the appropriate `ModuleInstance` structure.
*   `<CallName>` is the `Name` field of the `ModuleCall`.
*   `<OutputName>` is the name passed to the `.Output()` method.
*   `<ExpectedAddress>` is the resulting string from `.String()`.
*   The two scenarios clearly distinguish between getting the `AbsOutputValue` and then further converting it to a `ConfigOutputValue`.

Next, I'll examine `internal/addrs/module_instance_test.go`.
