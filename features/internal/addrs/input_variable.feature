# Metadata:
# Covers: internal/addrs/input_variable.go
# Behavior derived from source code analysis as no dedicated test file was found.

Feature: Input Variable Addressing and Transformations
  This feature describes how input variables are addressed and how their
  addresses can be transformed into absolute or configuration-specific forms.

  Scenario: InputVariable String Representation
    Given an InputVariable named "my_var"
    When its string representation is generated
    Then the result should be "var.my_var"

  Scenario: Absolute Input Variable Instance Address
    Given an InputVariable named "my_var"
    And a ModuleInstance address "module.child"
    When the InputVariable is made absolute to the ModuleInstance
    Then the resulting AbsInputVariableInstance string should be "module.child.var.my_var"

  Scenario: Absolute Input Variable Instance Address (Root Module)
    Given an InputVariable named "my_var"
    And a RootModuleInstance
    When the InputVariable is made absolute to the RootModuleInstance
    Then the resulting AbsInputVariableInstance string should be "var.my_var"

  Scenario: Config Input Variable Address
    Given an InputVariable named "my_var"
    And a Module configuration path "module.child"
    When the InputVariable is associated with the Module configuration path
    Then the resulting ConfigInputVariable string should be "module.child.var.my_var"

  Scenario: Config Input Variable Address (Root Module)
    Given an InputVariable named "my_var"
    And a RootModule configuration path
    When the InputVariable is associated with the RootModule configuration path
    Then the resulting ConfigInputVariable string should be "var.my_var"

  Scenario: Checkable Properties of AbsInputVariableInstance
    Given an AbsInputVariableInstance for "var.test_val" in module "module.check_mod"
    When its CheckableKind is requested
    Then it should be "CheckableInputVariable"
    When its ConfigCheckable representation is requested
    Then its string representation should be "module.check_mod.var.test_val"
    And its CheckableKind should also be "CheckableInputVariable"

  Scenario: Checkable Properties of ConfigInputVariable
    Given a ConfigInputVariable for "var.cfg_val" in module configuration "module.cfg_mod"
    When its CheckableKind is requested
    Then it should be "CheckableInputVariable"
