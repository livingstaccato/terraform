# Source Go File: internal/lang/types/type_type.go
# Source Go Test: None directly in this package. Behavior inferred from code.

Feature: Terraform Type Representation in cty
  This feature describes how Terraform uses cty to represent its own type information
  as a value, particularly for use in the Terraform console.

  Scenario: Representing a cty.Type as a cty.Value
    Given the Terraform type system needs to treat types themselves as values
    When a cty.Type needs to be represented as a cty.Value
    Then it is encapsulated using the "TypeType" capsule
    And this capsule is identified by the name "type"
    And this capsule holds an underlying Go type of `reflect.TypeOf(cty.Type{})`
    And this allows functions like the console `type()` function to return and display type information.
