# Source Go File: internal/configs/hcl2shim/values.go
# Source Go Test: internal/configs/hcl2shim/values_test.go

Feature: HCL2 Shim Value Conversions
  This feature describes the conversion of cty.Value objects to and from
  legacy Go interface{}-based representations, as defined in
  `internal/configs/hcl2shim/values.go`. This is primarily for
  compatibility with older parts of Terraform, like helper/schema.

  Background:
    Given the HCL2 shim environment

  Scenario Outline: Converting cty.Value to legacy config value using ConfigValueFromHCL2
    Given a cty.Value representing <CtyValueDescription>
    When ConfigValueFromHCL2 is called with this cty.Value
    Then the result should be the legacy interface{} value <ExpectedLegacyValueJSON>

    Examples:
      | CtyValueDescription                                       | ExpectedLegacyValueJSON                                                                 |
      | True                                                      | true                                                                                    |
      | False                                                     | false                                                                                   |
      | NumberIntVal 12                                           | 12                                                                                      |
      | NumberFloatVal 12.5                                       | 12.5                                                                                    |
      | StringVal "hello world"                                   | "\"hello world\""                                                                       |
      | ObjectVal {"name":"Ermintrude", "age":19, "address": {...}}| "{\"address\":{\"city\":\"Fridgewater\",\"state\":\"MA\",\"street\":[\"421 Shoreham Loop\"],\"zip\":\"91037\"},\"age\":19,\"name\":\"Ermintrude\"}" | # Nested object example from test
      | MapVal {"foo":"bar", "bar":"baz"}                         | "{\"bar\":\"baz\",\"foo\":\"bar\"}"                                                      |
      | TupleVal ["foo", True]                                    | "[\"foo\",true]"                                                                        |
      | NullVal(String)                                           | null                                                                                    |
      | UnknownVal(String)                                        | "\"74D93920-ED26-11E3-AC10-0800200C9A66\""                                               | # UnknownVariableValue

  Scenario Outline: Converting legacy config value to cty.Value using HCL2ValueFromConfigValue
    Given a legacy interface{} value <LegacyValueDescription> represented by JSON <LegacyValueJSON>
    When HCL2ValueFromConfigValue is called with this legacy value
    Then the result should be a cty.Value equivalent to <ExpectedCtyValueDescription>

    Examples:
      | LegacyValueDescription | LegacyValueJSON                                              | ExpectedCtyValueDescription              |
      | nil                    | null                                                         | NullVal(DynamicPseudoType)               |
      | UnknownVariableValue   | "\"74D93920-ED26-11E3-AC10-0800200C9A66\""                   | DynamicVal                               |
      | true                   | true                                                         | True                                     |
      | false                  | false                                                        | False                                    |
      | int 12                 | 12                                                           | NumberIntVal 12                          |
      | float64 12.5           | 12.5                                                         | NumberFloatVal 12.5                      |
      | string "hello world"   | "\"hello world\""                                            | StringVal "hello world"                  |
      | string "O\\u0308"       | "\"O\\u0308\""                                               | StringVal "\\u00D6"                       | # NFC normalized
      | empty slice            | "[]"                                                         | EmptyTupleVal                            |
      | nil slice              | "null" # Assuming HCL2ValueFromConfigValue gets actual nil   | EmptyTupleVal                            | # Test case shows []interface{}(nil) -> EmptyTupleVal
      | slice ["hello", "world"] | "[\"hello\",\"world\"]"                                      | TupleVal [StringVal "hello", StringVal "world"] |
      | empty map              | "{}"                                                         | EmptyObjectVal                           |
      | nil map                | "null" # Assuming HCL2ValueFromConfigValue gets actual nil   | EmptyObjectVal                           | # Test case shows map[string]interface{}(nil) -> EmptyObjectVal
      | map {"foo":"bar"}      | "{\"foo\":\"bar\"}"                                          | ObjectVal {"foo":StringVal "bar"}        |

  Scenario Outline: Converting cty.Object to legacy block config using ConfigValueFromHCL2Block
    Given a cty.ObjectValue <CtyObjectJSON>
    And a configschema.Block definition <SchemaJSON>
      # SchemaJSON will need to define attributes and block_types with their respective schemas and nesting modes
    When ConfigValueFromHCL2Block is called with the cty.ObjectValue and schema
    Then the result should be the legacy map[string]interface{} <ExpectedLegacyMapJSON>
    # Note: Panics if cty.Value is not a known object or doesn't conform to schema

    Examples:
      | CtyObjectJSON                                                                                                | SchemaJSON                                                                                                                                                                                                                                                          | ExpectedLegacyMapJSON                                                                                                    |
      | "{\"name\":\"Ermintrude\", \"age\":19, \"address\":{\"street\":[\"421 Shoreham Loop\"],\"city\":\"Fridgewater\",\"state\":\"MA\",\"zip\":\"91037\"}}" | "{\"attributes\":{\"name\":{\"type\":\"string\",\"optional\":true},\"age\":{\"type\":\"number\",\"optional\":true}},\"block_types\":{\"address\":{\"nesting\":\"NestingSingle\",\"block\":{\"attributes\":{\"street\":{\"type\":[\"list\",\"string\"],\"optional\":true},\"city\":{\"type\":\"string\",\"optional\":true},\"state\":{\"type\":\"string\",\"optional\":true},\"zip\":{\"type\":\"string\",\"optional\":true}}}}}" | "{\"address\":{\"city\":\"Fridgewater\",\"state\":\"MA\",\"street\":[\"421 Shoreham Loop\"],\"zip\":\"91037\"},\"age\":19,\"name\":\"Ermintrude\"}" |
      | "{\"name\":\"Ermintrude\", \"age\":19, \"address\":null}"                                                       | "{\"attributes\":{\"name\":{\"type\":\"string\",\"optional\":true},\"age\":{\"type\":\"number\",\"optional\":true}},\"block_types\":{\"address\":{\"nesting\":\"NestingSingle\",\"block\":{\"attributes\":{\"street\":{\"type\":[\"list\",\"string\"]}}}}}}" | "{\"age\":19,\"name\":\"Ermintrude\"}"                                                                                   | # Null block is omitted
      | "{\"name\":\"Ermintrude\", \"age\":19, \"address\":{\"zip\":null}}"                                               | "{\"attributes\":{\"name\":{\"type\":\"string\",\"optional\":true},\"age\":{\"type\":\"number\",\"optional\":true}},\"block_types\":{\"address\":{\"nesting\":\"NestingSingle\",\"block\":{\"attributes\":{\"zip\":{\"type\":\"string\",\"optional\":true}}}}}}" | "{\"age\":19,\"name\":\"Ermintrude\",\"address\":{}}"                                                                     | # Null attribute within block is omitted
      | "{\"address\":[{}]}"                                                                                           | "{\"block_types\":{\"address\":{\"nesting\":\"NestingList\",\"block\":{}}}}"                                                                                                                                                                              | "{\"address\":[{}]}"                                                                                                     | # List with one empty block
      | "{\"address\":[]}"                                                                                             | "{\"block_types\":{\"address\":{\"nesting\":\"NestingList\",\"block\":{}}}}"                                                                                                                                                                              | "{}"                                                                                                                     | # Empty list of blocks is omitted
      | "{\"address\":null}" # cty.NullVal(cty.EmptyObject) for the top level input                                   | "{}"                                                                                                                                                                                                                                                          | null                                                                                                                     | # Null input object

  # Helper step definitions will be needed to parse JSON representations into cty.Value, configschema.Block, and map[string]interface{}
  # and to compare the results (potentially with deep equality checks for maps/slices).
  # The CtyObjectJSON for ConfigValueFromHCL2Block needs to represent the cty.Value used in tests (e.g., cty.ObjectVal(...)).
  # The SchemaJSON needs to represent the configschema.Block structure.
  # ExpectedLegacyValueJSON and ExpectedLegacyMapJSON represent the `map[string]interface{}` or `interface{}` from Go tests, serialized to JSON for comparison.
  # The "address":{...} in the first ConfigValueFromHCL2 example is a cty.ObjectVal, not a map, for the "address" attribute.
  # The example `ObjectVal {"name":"Ermintrude", "age":19, "address": {...}}` needs careful translation in step definitions.
  # For ConfigValueFromHCL2Block, the "address" block type example:
  # Input: cty.ObjectVal(map[string]cty.Value{"address": cty.ObjectVal(map[string]cty.Value{"street": cty.ListVal(...)})})
  # Schema: BlockTypes: {"address": {Nesting: NestingSingle, Block: {Attributes: {"street": ...}}}}
  # Output: map[string]interface{}{"address": map[string]interface{}{"street": []interface{}{...}}}
  # The UnknownVariableValue is "74D93920-ED26-11E3-AC10-0800200C9A66".
  # Number precision for ConfigValueFromHCL2: int if exact and fits, else float64.
  # HCL2ValueFromConfigValue for int becomes NumberIntVal, float64 becomes NumberFloatVal.
