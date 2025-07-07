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
      | `{"name": {"type": "String", "value": "Terraform"}, "unsupported_attr": {"type": "Set<String>", "value": ["a", "b"]}}` | name=Terraform                     |
      | `{"name": {"type": "String", "value": "Terraform"}, "nested_obj": {"type": "Object", "value": {"key": {"type":"String", "value":"val"}}}}` | name=Terraform                     |

  Scenario: Converting cty.Object with an unsupported attribute type (e.g., a Set)
    Given a cty.ObjectValue with the following attributes and values:
      | key              | type         | value      |
      | "name"           | String       | "Terraform"|
      | "unsupported_set"| Set(String)  | ["a", "b"] |
      | "age"            | Number       | 10         |
    When ObjectToString is called with this cty.ObjectValue
    # Attributes of types not explicitly handled by the switch in ObjectToString are omitted.
    # The order of "age" and "name" in the output string depends on map iteration order.
    # For consistency with other tests, we'll assume alphabetical ordering for the expected result.
    Then the resulting string should be "age=10,name=Terraform"

  Scenario: Converting cty.Object with a nested object attribute (unsupported)
    Given a cty.ObjectValue with the following attributes and values:
      | key           | type                                     | value                     |
      | "id"          | String                                   | "item1"                   |
      | "nested_data" | Object({"attr1": String, "attr2": Number}) | {"attr1": "val1", "attr2": 100} |
    When ObjectToString is called with this cty.ObjectValue
    # Nested objects are not handled by any case in the switch and are thus omitted.
    Then the resulting string should be "id=item1"

  Scenario: Converting a non-object cty.Value (should panic)
    Given a cty.StringValue "this is not an object"
    When ObjectToString is called with this non-object value
    Then the operation should result in a panic
      # This is a negative test case; the exact panic message can be specified if needed.
      # The Go test would use `defer func() { recover() }()` to catch this.
      # For BDD, we state the expectation of a panic.
      # The Go code has: panic("not an object")
