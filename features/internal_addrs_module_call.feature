# Source Go File: internal/addrs/module_call.go
# Source Go Test: internal/addrs/module_call_test.go

Feature: Absolute Module Call Addressing
  This feature describes how Terraform constructs addresses for outputs
  belonging to a module call, using the AbsModuleCall type.

  Background:
    Given the Terraform addressing system for module calls

  Scenario Outline: Constructing an AbsOutputValue from an AbsModuleCall
    Given an AbsModuleCall defined with Parent Module Path "<ParentModulePath>" and Call Name "<CallName>"
    And an output name "<OutputName>"
    When the Output method is called on the AbsModuleCall with the output name
    Then the resulting AbsOutputValue should have a string representation of "<ExpectedAbsOutputValueString>"

    Examples:
      | ParentModulePath | CallName | OutputName | ExpectedAbsOutputValueString |
      | ""               | "hello"  | "foo"      | "module.hello.foo"           |
      | "module.child"   | "hello"  | "foo"      | "module.child.module.hello.foo" |
      | "module.parent[0]" | "api"  | "endpoint" | "module.parent[0].module.api.endpoint" |

  Scenario Outline: Constructing a ConfigOutputValue from an AbsModuleCall's output
    Given an AbsModuleCall defined with Parent Module Path "<ParentModulePath>" and Call Name "<CallName>"
    And an output name "<OutputName>"
    When the Output method is called on the AbsModuleCall with the output name, producing an AbsOutputValue
    And the ConfigOutputValue method is called on this AbsOutputValue
    Then the resulting ConfigOutputValue should have a string representation of "<ExpectedConfigOutputValueString>"

    Examples:
      | ParentModulePath | CallName | OutputName | ExpectedConfigOutputValueString      |
      | ""               | "hello"  | "foo"      | "module.hello.output.foo"            |
      | "module.child"   | "hello"  | "foo"      | "module.child.module.hello.output.foo" |
      | "module.parent[0]" | "api"  | "endpoint" | "module.parent[0].module.api.output.endpoint" |

  # Note:
  # - ParentModulePath is a string representation of an addrs.ModuleInstance.
  # - Step definitions will need to parse these strings into addrs.ModuleInstance and construct addrs.AbsModuleCall.
  # - The cty aspects are indirect, as these address types are fundamental to how Terraform organizes
  #   and references configuration, state, and plan, which often involve cty.Value.
  # - This feature focuses on the string representation and correct construction of derived addresses.
