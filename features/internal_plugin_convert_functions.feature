# Source Go File: internal/plugin/convert/functions.go
# Source Go Test: internal/plugin/convert/functions_test.go

Feature: Provider Function Declaration Conversion
  This feature describes how Terraform provider function declarations (providers.FunctionDecl)
  are converted to and from the tfplugin5 Protobuf format. This involves handling
  parameters (including variadic), return types, descriptions, and cty.Type representations.

  Background:
    Given the plugin function declaration conversion context

  Scenario Outline: Converting providers.FunctionDecl to proto.Function and back
    Given a providers.FunctionDecl named "<FunctionName>" with details:
      <FunctionDetailsTable>
      # Table columns: ParamName, ParamTypeJSON, ParamAllowNull, ParamAllowUnknown, ParamDescription, ParamDescriptionKind, IsVariadic
      #                ReturnTypeJSON, FuncDescription, FuncDescriptionKind, Summary, DeprecationMessage
    When FunctionDeclToProto is called with this declaration
    Then the resulting proto.Function should correctly represent the declaration
      # (Verification might involve checking specific proto fields or converting back)
    When the resulting proto.Function is converted back using FunctionDeclFromProto
    Then the final providers.FunctionDecl should be equivalent to the original declaration

    Examples:
      | FunctionName | FunctionDetailsTable                                                                                                                                                                                            |
      | "basic_string_func" | {"Parameters": [{"ParamName":"input_str", "ParamTypeJSON":"\"string\"", "ParamAllowNull":true, "ParamAllowUnknown":true, "ParamDescription":"A string input", "ParamDescriptionKind":"StringPlain"}], "ReturnTypeJSON":"\"string\"", "FuncDescription":"Returns the input string.", "FuncDescriptionKind":"StringPlain"} |
      | "variadic_strings_func" | {"VariadicParameter": {"ParamName":"inputs", "ParamTypeJSON":"\"string\"", "ParamDescription":"Multiple string inputs", "ParamDescriptionKind":"StringMarkdown"}, "ReturnTypeJSON":"\"string\"", "FuncDescription":"Joins strings.", "FuncDescriptionKind":"StringMarkdown"} |
      | "no_params_returns_num" | {"ReturnTypeJSON":"\"number\"", "FuncDescription":"Returns a number.", "FuncDescriptionKind":"StringPlain"} |
      | "complex_types_func" | {"Parameters": [{"ParamName":"data", "ParamTypeJSON":"[\"map\", \"bool\"]"}], "ReturnTypeJSON":"[\"list\", \"number\"]", "FuncDescription":"Processes map to list."} |

  Scenario: Converting a map of providers.FunctionDecl to proto.Function map and back
    Given a map of providers.FunctionDecl:
      | FunctionName          | Details (simplified JSON for BDD)                                                                                                                                                             |
      | "func_one"            | "{\"Parameters\":[{\"ParamName\":\"p1\",\"ParamTypeJSON\":\"\\\"string\\\"\"}],\"ReturnTypeJSON\":\"\\\"bool\\\"\",\"FuncDescription\":\"Desc one\"}"                                              |
      | "func_two_variadic"   | "{\"VariadicParameter\":{\"ParamName\":\"vp\",\"ParamTypeJSON\":\"\\\"number\\\"\"},\"ReturnTypeJSON\":\"\\\"string\\\"\",\"FuncDescription\":\"Desc two\"}"                                    |
    When FunctionDeclsToProto is called with this map
    Then the resulting map of proto.Function should have 2 entries
    And entry "func_one" should correctly represent its declaration
    And entry "func_two_variadic" should correctly represent its declaration
    When the resulting proto.Function map is converted back using FunctionDeclsFromProto
    Then the final map of providers.FunctionDecl should be equivalent to the original map

  Scenario: Handling invalid type JSON during conversion from proto
    Given a proto.Function_Parameter with an invalid JSON string for its Type field (e.g., "not a valid json type")
    When functionParamFromProto (or by extension FunctionDeclFromProto) is called
    Then an error should occur indicating "invalid type constraint"

  Scenario: Handling invalid return type JSON during conversion from proto
    Given a proto.Function with an invalid JSON string for its Return.Type field
    When FunctionDeclFromProto is called
    Then an error should occur indicating "invalid return type constraint"

  # Helper step definitions will be needed to:
  # - Parse <FunctionDetailsTable> or JSON strings into providers.FunctionDecl and its sub-structures like providers.FunctionParam.
  #   This includes parsing ParamTypeJSON and ReturnTypeJSON into cty.Type.
  # - Compare providers.FunctionDecl objects for equivalence (e.g., using cmp with ctydebug.CmpOptions).
  # - Compare proto.Function objects (potentially by checking key fields or doing a proto comparison).
  # - For map scenarios, iterate and check individual function declarations.
  # - Simulate errors by providing malformed proto messages for error case scenarios.
  # - StringKind enums (StringPlain, StringMarkdown) need to be handled.
  # - Note: Proto messages have fields like `AllowNullValue` and `AllowUnknownValues` which map directly.
  # - JSON for cty.Type (e.g., "\"string\"", "[\"list\",\"bool\"]") needs to be correctly embedded/extracted.
