# Source Go File: internal/configs/hcl2shim/flatmap.go
# Source Go Test: internal/configs/hcl2shim/flatmap_test.go

Feature: HCL2 Shim Flatmap Conversions
  This feature describes the conversion of cty.Value objects (specifically objects)
  to and from the "flatmap" format (map[string]string), which is used for
  legacy compatibility, particularly with helper/schema.

  Background:
    Given the HCL2 shim environment for flatmap conversions
    And the UnknownVariableValue is "74D93920-ED26-11E3-AC10-0800200C9A66"

  Scenario Outline: Converting cty.Object to flatmap using FlatmapValueFromHCL2
    Given a cty.Value representing <CtyValueDescription> as a cty.Object
    When FlatmapValueFromHCL2 is called with this cty.Object
    Then the result should be a flatmap equivalent to <ExpectedFlatmapJSON>
    # Note: Panics if input is not an object type.

    Examples:
      | CtyValueDescription                                                      | ExpectedFlatmapJSON                                                                                                |
      | EmptyObjectVal                                                           | "{}"                                                                                                               |
      | ObjectVal {"foo": StringVal "hello"}                                     | "{\"foo\":\"hello\"}"                                                                                              |
      | ObjectVal {"foo": UnknownVal(Bool)}                                      | "{\"foo\":\"74D93920-ED26-11E3-AC10-0800200C9A66\"}"                                                               |
      | ObjectVal {"foo": NumberIntVal 12}                                       | "{\"foo\":\"12\"}"                                                                                                 |
      | ObjectVal {"foo": True, "bar": False}                                    | "{\"bar\":\"false\",\"foo\":\"true\"}"                                                                             | # Order may vary
      | ObjectVal {"foo": ListValEmpty(String)}                                  | "{\"foo.#\":\"0\"}"                                                                                                |
      | ObjectVal {"foo": UnknownVal(List(String))}                              | "{\"foo.#\":\"74D93920-ED26-11E3-AC10-0800200C9A66\"}"                                                              |
      | ObjectVal {"foo": ListVal [StringVal "hello"]}                           | "{\"foo.#\":\"1\",\"foo.0\":\"hello\"}"                                                                            |
      | ObjectVal {"foo": MapVal {"hello":NumInt 12, "hello.world":NumInt 10}}   | "{\"foo.%\":\"2\",\"foo.hello\":\"12\",\"foo.hello.world\":\"10\"}"                                                |
      | ObjectVal {"foo": UnknownVal(Map(String))}                               | "{\"foo.%\":\"74D93920-ED26-11E3-AC10-0800200C9A66\"}"                                                              |
      | ObjectVal {"foo": SetVal [StringVal "hello", StringVal "world"]}         | "{\"foo.#\":\"2\",\"foo.0\":\"hello\",\"foo.1\":\"world\"}"                                                        | # Set elements are ordered for flatmap
      | ObjectVal {"foo": UnknownVal(Set(Number))}                               | "{\"foo.#\":\"74D93920-ED26-11E3-AC10-0800200C9A66\"}"                                                              |
      | ObjectVal {"foo": ListVal [Obj{"bar":"h","baz":"w"}, Obj{"bar":"b","baz":"B"}]} | "{\"foo.#\":\"2\",\"foo.0.bar\":\"h\",\"foo.0.baz\":\"w\",\"foo.1.bar\":\"b\",\"foo.1.baz\":\"B\"}"              | # Nested objects in list
      | ObjectVal {"foo": ListVal [UnknownVal(Object{"bar":Str,"baz":List(Bool),"bap":Map(Num)})]} | "{\"foo.#\":\"1\",\"foo.0.bar\":\"74D93920-ED26-11E3-AC10-0800200C9A66\",\"foo.0.baz.#\":\"74D93920-ED26-11E3-AC10-0800200C9A66\",\"foo.0.bap.%\":\"74D93920-ED26-11E3-AC10-0800200C9A66\"}" |
      | NullVal(Object{"foo": Set(Object{"bar": String})})                       | null                                                                                                               |

  Scenario Outline: Converting flatmap to cty.Object using HCL2ValueFromFlatmap
    Given a flatmap <FlatmapJSON>
    And a target cty.Type <TargetCtyTypeDescription>
    When HCL2ValueFromFlatmap is called with this flatmap and target type
    Then the result should be a cty.Value equivalent to <ExpectedCtyValueDescription>
    And no error should occur
    # Note: Panics if target type is not an object type.

    Examples:
      | FlatmapJSON                                                          | TargetCtyTypeDescription                                 | ExpectedCtyValueDescription                                                                 |
      | "{}"                                                                 | EmptyObject                                              | EmptyObjectVal                                                                              |
      | "{\"foo\":\"blah\",\"bar\":\"true\",\"baz\":\"12.5\",\"unk\":\"74D93920-ED26-11E3-AC10-0800200C9A66\"}" | Object{"foo":Str,"bar":Bool,"baz":Num,"unk":Bool}        | ObjectVal{"foo":StrVal "blah","bar":True,"baz":NumFloat 12.5,"unk":UnknownVal(Bool)} |
      | "{\"foo.#\":\"0\"}"                                                  | Object{"foo":List(String)}                               | ObjectVal{"foo":ListValEmpty(String)}                                                      |
      | "{\"foo.#\":\"74D93920-ED26-11E3-AC10-0800200C9A66\"}"                | Object{"foo":List(String)}                               | ObjectVal{"foo":UnknownVal(List(String))}                                                  |
      | "{\"foo.#\":\"1\",\"foo.0\":\"hello\"}"                               | Object{"foo":List(String)}                               | ObjectVal{"foo":ListVal [StrVal "hello"]}                                                  |
      | "{\"foo.#\":\"2\",\"foo.0\":\"true\",\"foo.1\":\"false\"}"             | Object{"foo":List(Bool)}                                 | ObjectVal{"foo":ListVal [True, False]}                                                      |
      | "{\"foo.#\":\"2\",\"foo.0\":\"hello\"}"                               | Object{"foo":Tuple([String,Bool])}                       | ObjectVal{"foo":TupleVal [StrVal "hello", NullVal(Bool)]}                                 |
      | "{\"foo.#\":\"0\"}"                                                  | Object{"foo":Set(String)}                                | ObjectVal{"foo":SetValEmpty(String)}                                                       |
      | "{\"foo.#\":\"1\",\"foo.24534534\":\"hello\"}"                        | Object{"foo":Set(String)}                                | ObjectVal{"foo":SetVal [StrVal "hello"]}                                                   |
      | "{\"foo.%\":\"0\"}"                                                  | Object{"foo":Map(String)}                                | ObjectVal{"foo":MapValEmpty(String)}                                                       |
      | "{\"foo.%\":\"2\",\"foo.baz\":\"true\",\"foo.bar.baz\":\"false\"}"     | Object{"foo":Map(Bool)}                                  | ObjectVal{"foo":MapVal {"baz":True,"bar.baz":False}}                                       |
      | "{\"foo.#\":\"1\"}"                                                  | Object{"foo":Set(Object{"bar":String})}                  | ObjectVal{"foo":SetVal [ObjectVal {"bar":NullVal(String)}]}                               | # Set of one emptyish object
      | "null"                                                               | Object{"foo":Set(Object{"bar":String})}                  | NullVal(Object{"foo":Set(Object{"bar":String})})                                           |

  Scenario Outline: Converting flatmap to cty.Object with errors using HCL2ValueFromFlatmap
    Given a flatmap <FlatmapJSON>
    And a target cty.Type <TargetCtyTypeDescription>
    When HCL2ValueFromFlatmap is called with this flatmap and target type
    Then an error should occur with message containing "<ExpectedErrorMessage>"

    Examples:
      | FlatmapJSON         | TargetCtyTypeDescription      | ExpectedErrorMessage                                                  |
      | "{\"foo.#\":\"not-valid\"}" | Object{"foo":List(String)}    | "invalid count value for \"foo.\" in state: strconv.Atoi: parsing \"not-valid\": invalid syntax" |

  Scenario Outline: Round trip conversion for flatmap and cty.Object
    Given an initial flatmap <InitialFlatmapJSON> for a cty.Object of type <TargetCtyTypeDescription>
    When HCL2ValueFromFlatmap is called with the initial flatmap and target type to get a cty.Value
    And FlatmapValueFromHCL2 is then called with the resulting cty.Value
    Then the final flatmap should be equivalent to <ExpectedRoundTripFlatmapJSON> (which might be the initial or a normalized version)

    Examples:
      | InitialFlatmapJSON | TargetCtyTypeDescription                                        | ExpectedRoundTripFlatmapJSON |
      | "{}"               | Object{"foo":Map(String),"bar":Set(String)}                     | "{}"                         |
      | null               | Object{"foo":Map(String),"bar":Set(String)}                     | null                         | # Null round trips to null
      | "{\"foo.baz.%\":\"1\",\"foo.baz.key\":\"val\"}" | Object{"foo":Object{"baz":Map(String),"biz":Map(String)},"bar":Set(String)} | "{\"foo.baz.%\":\"1\",\"foo.baz.key\":\"val\"}" | # Partial flatmap

  # Helper step definitions will be needed for:
  # - Parsing <CtyValueDescription> and <ExpectedCtyValueDescription> into cty.Value.
  # - Parsing <ExpectedFlatmapJSON>, <FlatmapJSON>, <InitialFlatmapJSON>, <ExpectedRoundTripFlatmapJSON> into map[string]string or handling null.
  # - Parsing <TargetCtyTypeDescription> into cty.Type.
  # - Comparing flatmaps (map[string]string) and cty.Values for equivalence.
  # - The UnknownVariableValue is "74D93920-ED26-11E3-AC10-0800200C9A66".
  # - Flatmap keys for lists/sets use "#" for count, and numerical indices (e.g., "foo.0").
  # - Flatmap keys for maps use "%" for count, and string keys (e.g., "foo.key").
  # - Nested structures are flattened with dot separators (e.g., "list_attr.0.nested_attr").
  # - For FlatmapValueFromHCL2, sets are serialized with ordered indices (0, 1, ...).
  # - For HCL2ValueFromFlatmap, set indices from flatmap are ignored for element values; only count matters.
  # - Null cty.Values are generally omitted from the flatmap, unless they are part of an unknown collection.
  # - Unknown cty.Values are represented by UnknownVariableValue.
  # - Unknown collections (list/map/set) have their count key ("#" or "%") set to UnknownVariableValue.
  # - Unknown objects result in all their attributes being marked as UnknownVariableValue in the flatmap.
