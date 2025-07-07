# Source Go File: internal/tfdiags/contextual.go
# Source Go Test: internal/tfdiags/contextual_test.go

Feature: Contextual Diagnostics with cty.Path
  Describes how Terraform uses cty.Path within diagnostics to pinpoint
  issues in configuration files and how these paths are elaborated
  to specific source code locations.

  Background:
    Given a configuration file "test.tf" with the following content:
    """
    foo {
      bar = "hi"
    }
    foo {
      bar = "bar"
    }
    bar {
      bar = "woot"
    }
    baz "a" {
      bar = "beep"
    }
    baz "b" {
      bar = "boop"
    }
    parent {
      nested_str = "hello"
      nested_str_tuple = ["aa", "bbb", "cccc"]
      nested_num_tuple = [1, 9863, 22]
      nested_map = {
        first_key  = "first_value"
        second_key = "2nd value"
      }
    }
    tuple_of_one = ["one"]
    tuple_of_two = ["first", "22222"]
    root_map = {
      first  = "1st"
      second = "2nd"
    }
    simple_attr = "val"
    """

  Scenario Outline: Elaborating AttributeValue diagnostics with cty.Path to source locations
    Given an AttributeValue diagnostic is created with severity "<Severity>", summary "<Summary>", detail "<Detail>"
    And the diagnostic refers to the cty.Path defined by steps: <PathSteps>
    When the diagnostics are elaborated within the "test.tf" configuration body with address "test.addr"
    Then the elaborated diagnostic should point to the source range in "test.tf" from line <StartLine> col <StartCol> to line <EndLine> col <EndCol>
    And the elaborated diagnostic detail address should be "test.addr"

    Examples:
      | Severity | Summary        | Detail   | PathSteps                                                                                                | StartLine | StartCol | EndLine | EndCol |
      | ERROR    | "foo[0].bar"   | "detail" | '[{"type": "GetAttr", "name": "foo"}, {"type": "Index", "key_type": "Number", "key_value": 0}, {"type": "GetAttr", "name": "bar"}]' | 3         | 9        | 3       | 13     |
      | ERROR    | "foo[1].bar"   | "detail" | '[{"type": "GetAttr", "name": "foo"}, {"type": "Index", "key_type": "Number", "key_value": 1}, {"type": "GetAttr", "name": "bar"}]' | 6         | 9        | 6       | 14     |
      | ERROR    | "foo[99].bar"  | "detail" | '[{"type": "GetAttr", "name": "foo"}, {"type": "Index", "key_type": "Number", "key_value": 99}, {"type": "GetAttr", "name": "bar"}]'| 1         | 1        | 1       | 1      | # Empty/MissingItemRange
      | ERROR    | "bar.bar"      | "detail" | '[{"type": "GetAttr", "name": "bar"}, {"type": "GetAttr", "name": "bar"}]'                               | 9         | 9        | 9       | 15     |
      | ERROR    | "baz[\"a\"].bar" | "detail" | '[{"type": "GetAttr", "name": "baz"}, {"type": "Index", "key_type": "String", "key_value": "a"}, {"type": "GetAttr", "name": "bar"}]' | 12        | 9        | 12      | 15     |
      | ERROR    | "baz[\"b\"].bar" | "detail" | '[{"type": "GetAttr", "name": "baz"}, {"type": "Index", "key_type": "String", "key_value": "b"}, {"type": "GetAttr", "name": "bar"}]' | 15        | 9        | 15      | 15     |
      | ERROR    | "baz[\"not_exists\"].bar" | "detail" | '[{"type": "GetAttr", "name": "baz"}, {"type": "Index", "key_type": "String", "key_value": "not_exists"}, {"type": "GetAttr", "name": "bar"}]' | 1         | 1        | 1       | 1      | # Empty/MissingItemRange
      | ERROR    | "parent.nested_str" | "detail" | '[{"type": "GetAttr", "name": "parent"}, {"type": "GetAttr", "name": "nested_str"}]'                   | 18        | 16       | 18      | 23     |
      | ERROR    | "parent.nested_str_tuple[0]" | "detail" | '[{"type": "GetAttr", "name": "parent"}, {"type": "GetAttr", "name": "nested_str_tuple"}, {"type": "Index", "key_type": "Number", "key_value": 0}]' | 19        | 23       | 19      | 27     |
      | ERROR    | "parent.nested_str_tuple[2]" | "detail" | '[{"type": "GetAttr", "name": "parent"}, {"type": "GetAttr", "name": "nested_str_tuple"}, {"type": "Index", "key_type": "Number", "key_value": 2}]' | 19        | 36       | 19      | 42     |
      | ERROR    | "parent.nested_str_tuple[99]" | "detail" | '[{"type": "GetAttr", "name": "parent"}, {"type": "GetAttr", "name": "nested_str_tuple"}, {"type": "Index", "key_type": "Number", "key_value": 99}]' | 19        | 3        | 19      | 19     | # Attribute NameRange for out of bounds
      | ERROR    | "parent.nested_map.first_key" | "detail" | '[{"type": "GetAttr", "name": "parent"}, {"type": "GetAttr", "name": "nested_map"}, {"type": "Index", "key_type": "String", "key_value": "first_key"}]' | 22        | 19       | 22      | 30     |
      | ERROR    | "parent.nested_map.undefined_key" | "detail" | '[{"type": "GetAttr", "name": "parent"}, {"type": "GetAttr", "name": "nested_map"}, {"type": "Index", "key_type": "String", "key_value": "undefined_key"}]' | 21        | 3        | 21      | 13     | # Attribute NameRange for missing key
      | ERROR    | "tuple_of_one[0]" | "detail" | '[{"type": "GetAttr", "name": "tuple_of_one"}, {"type": "Index", "key_type": "Number", "key_value": 0}]' | 26        | 17       | 26      | 22     |
      | ERROR    | "tuple_of_one[null]" | "detail" | '[{"type": "GetAttr", "name": "tuple_of_one"}, {"type": "Index", "key_type": "Null", "key_value": "Number"}]' | 26        | 1        | 26      | 13     | # Attribute NameRange for null index
      | ERROR    | "simple_attr"  | "detail" | '[{"type": "GetAttr", "name": "simple_attr"}]'                                                          | 32        | 15       | 32      | 20     |

  Scenario: Retrieving cty.Path from an AttributeValue diagnostic
    Given an AttributeValue diagnostic is created with severity "ERROR", summary "Test Summary", detail "Test Detail"
    And the diagnostic refers to the cty.Path with a GetAttrStep named "foo" followed by an IndexStep with number key 0 followed by a GetAttrStep named "bar"
    When GetAttribute is called on the diagnostic
    Then the returned cty.Path should have a GetAttrStep named "foo"
    And the second step should be an IndexStep with number key 0
    And the third step should be a GetAttrStep named "bar"

  Scenario: Elaborating an AttributeValue diagnostic that already has a subject
    Given an AttributeValue diagnostic is created for cty.Path with GetAttrStep "foo"
    And the diagnostic already has a subject range "somewhere_else.tf" from line 1 col 1 to line 1 col 10
    And the diagnostic has an original address "original_address"
    When the diagnostics are elaborated within the "test.tf" configuration body with address "new.addr"
    Then the elaborated diagnostic should still point to the source range in "somewhere_else.tf" from line 1 col 1 to line 1 col 10
    And the elaborated diagnostic detail address should be "original_address"

  Scenario: Elaborating an AttributeValue diagnostic with a missing (empty) cty.Path
    Given an AttributeValue diagnostic is created with severity "ERROR", summary "Missing Path", detail "Detail"
    And the diagnostic refers to an empty cty.Path
    When the diagnostics are elaborated within the "test.tf" configuration body with address "test.addr"
    Then the elaborated diagnostic subject should be nil or represent a default whole-body range

  Scenario: Elaborating WholeContainingBody diagnostic
    Given a WholeContainingBody diagnostic is created with severity "WARNING", summary "Whole Body Warning", detail "This applies to the whole body"
    When the diagnostics are elaborated within the "test.tf" configuration body with address "module.test"
    Then the elaborated diagnostic should point to the missing item range of the "test.tf" body
    And the elaborated diagnostic detail address should be "module.test"

  Scenario: Path traversal with only an IndexStep (should default to body range)
    Given an AttributeValue diagnostic is created with severity "ERROR", summary "Index Only", detail "Detail"
    And the diagnostic refers to the cty.Path defined by steps: '[{"type": "Index", "key_type": "String", "key_value": "key"}]'
    When the diagnostics are elaborated within the "test.tf" configuration body with address "test.addr"
    Then the elaborated diagnostic should point to the source range in "test.tf" from line 1 col 1 to line 1 col 1 # Empty/MissingItemRange for the whole body
    And the elaborated diagnostic detail address should be "test.addr"

  Scenario: Path traversal with multiple IndexSteps (should default to body range)
    Given an AttributeValue diagnostic is created with severity "ERROR", summary "Multiple Index Only", detail "Detail"
    And the diagnostic refers to the cty.Path defined by steps: '[{"type": "Index", "key_type": "String", "key_value": "key"}, {"type": "Index", "key_type": "String", "key_value": "another"}]'
    When the diagnostics are elaborated within the "test.tf" configuration body with address "test.addr"
    Then the elaborated diagnostic should point to the source range in "test.tf" from line 1 col 1 to line 1 col 1 # Empty/MissingItemRange for the whole body
    And the elaborated diagnostic detail address should be "test.addr"
