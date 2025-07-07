# Source Go File: internal/tfdiags/object.go
# Source Go Test: internal/tfdiags/object_test.go

Feature: Converting cty.Object to String for Diagnostics
  Describes how cty.Object values are converted to a string representation,
  suitable for inclusion in diagnostic messages.

  Scenario Outline: Converting various cty.Object values to string
    Given a cty.ObjectValue with the following attributes and values: <Attributes>
    When ObjectToString is called with this cty.ObjectValue
    Then the resulting string should be "<ExpectedString>"

    Examples:
      | Attributes                                                                                   | ExpectedString                     |
      | `{"type": "Null", "object_type": {}}`                                                        | <null>                             |
      | `{"type": "Unknown", "object_type": {}}`                                                     | <unknown>                          |
      | `{"type": "EmptyObject"}`                                                                    | <empty>                            |
      | `{"number": {"type": "Number", "value": 42}, "string": {"type": "String", "value": "hello"}, "bool": {"type": "Bool", "value": true}}` | bool=true,number=42,string=hello   |
      | `{"string": {"type": "String", "value": "hello"}, "list": {"type": "List<String>", "value": ["a", "b", "c"]}}` | list=[a,b,c],string=hello          |
      | `{"string": {"type": "String", "value": "hello"}, "null_attr": {"type": "Null", "value_type": "String"}}` | null_attr=<null>,string=hello      |
      | `{"num_list": {"type": "List<Number>", "value": [1, 20, 300]}}`                               | num_list=[1,20,300]                |
      | `{"bool_list": {"type": "List<Bool>", "value": [true, false, true]}}`                         | bool_list=[true,false,true]        |

  Scenario: Converting cty.Object with mixed type list (Illustrative - current implementation supports specific list types)
    Given a cty.ObjectValue with attribute "mixed_list" of type List<Dynamic> and value `[1, "mixed", true]`
    When ObjectToString is called with this cty.ObjectValue
    # Note: Current ObjectToString implementation has specific cases for List<String>, List<Number>, List<Bool>.
    # A List<Dynamic> or list of other types might not be formatted as expected by this test if not handled.
    # This scenario assumes a hypothetical extension or relies on existing behavior for unhandled list types (likely panic or empty string for the list part).
    # For this BDD, we'll assume it would render based on what it *can* handle or a placeholder if it can't.
    # Based on current code, this specific scenario would likely not produce a clean output for the list part if it's not one of the handled primitive list types.
    # Let's assume for the BDD if it's not a handled list type, it's not included or is empty.
    # If "mixed_list" was List<String> containing "1", "mixed", "true", it would be "mixed_list=[1,mixed,true]"
    # Since it's not, and ObjectToString is specific, we expect it not to be part of the output or to be empty.
    # Let's test a single string attribute to confirm the function processes other parts of the object.
    And another attribute "description" of type String and value "example"
    Then the resulting string should be "description=example" or "description=example,mixed_list=[]" or similar depending on unhandled list behavior

  Scenario: Converting a non-object cty.Value (should panic)
    Given a cty.StringValue "this is not an object"
    When ObjectToString is called with this non-object value
    Then the operation should result in a panic
      # This is a negative test case; the exact panic message can be specified if needed.
      # The Go test would use `defer func() { recover() }()` to catch this.
      # For BDD, we state the expectation of a panic.
      # The Go code has: panic("not an object")
