# Source Go File: internal/terraform/eval_for_each.go
# Source Go Test: internal/terraform/eval_for_each_test.go

Feature: Evaluate For-Each Expression
  This feature describes how Terraform evaluates HCL expressions provided for "for_each"
  meta-arguments on resources, modules, and import blocks. It covers type checking,
  handling of unknown values, and various cty value markings.

  Background:
    Given an evaluation context

  Scenario Outline: Evaluating valid for_each expressions for resources (allowUnknown = false)
    Given an HCL expression that evaluates to <CtyValueDescription>
    And allowUnknown is false for resource evaluation
    When evaluateForEachExpression is called
    Then the resulting for_each map should be <ExpectedMapJSON>
    And the result should be fully known
    And no diagnostics should be produced

    Examples:
      | CtyValueDescription                 | ExpectedMapJSON                        |
      | Empty StringSet                     | {}                                     |
      | StringSet: ["a", "b"]               | {"a":"a", "b":"b"}                     |
      | Empty Map (String to Bool)          | {}                                     |
      | Map: {"a":true, "b":false}          | {"a":true, "b":false}                  |
      | Map with Unknown Bool values: {"x": UnknownBool, "y": UnknownBool} | {"x":"(unknown)", "y":"(unknown)"}   | # Values can be unknown if keys are known
      | Map with Sensitive Bool values: {"s": SensitiveTrue, "r": false} | {"s":"(sensitive)", "r":false}         | # Values can be sensitive
      # Note: Ephemeral values in the map would be an error, tested separately. Object types also valid.

  Scenario Outline: Evaluating invalid for_each expressions for resources (allowUnknown = false)
    Given an HCL expression that evaluates to <CtyValueDescription>
    And allowUnknown is false for resource evaluation
    When evaluateForEachExpression is called
    Then an error diagnostic should occur with summary "<ExpectedSummary>" and detail containing "<ExpectedDetailSubstring>"
    And the diagnostic should indicate <CausedByFlags> if applicable

    Examples:
      | CtyValueDescription                 | ExpectedSummary                 | ExpectedDetailSubstring                                                                 | CausedByFlags                     |
      | Null StringSet                      | Invalid for_each argument       | `the given "for_each" argument value is null`                                           |                                   |
      | String "not a collection"           | Invalid for_each argument       | `must be a map, or set of strings, and you have provided a value of type string`        |                                   |
      | List of Strings ["a", "b"]          | Invalid for_each argument       | `must be a map, or set of strings, and you have provided a value of type list`          |                                   |
      | Tuple of Strings ["a", "b"]         | Invalid for_each argument       | `must be a map, or set of strings, and you have provided a value of type tuple`         |                                   |
      | Unknown StringSet                   | Invalid for_each argument       | `set includes values derived from resource attributes that cannot be determined`        | CausedByUnknown                   |
      | Unknown Map (String to Bool)        | Invalid for_each argument       | `map includes keys derived from resource attributes that cannot be determined`          | CausedByUnknown                   |
      | Map (String to Bool) marked Sensitive | Invalid for_each argument       | `Sensitive values, or values derived from sensitive values, cannot be used`             | CausedBySensitive                 |
      | Map (String to Bool) marked Ephemeral | Invalid for_each argument       | `The given "for_each" value is derived from an ephemeral value`                         | CausedByEphemeral                 |
      | Set of Booleans [true, false]       | Invalid for_each set argument   | `supports maps and sets of strings, but you have provided a set containing type bool`   |                                   |
      | StringSet with a Null value         | Invalid for_each set argument   | `must not contain null values`                                                          |                                   |
      | StringSet with an Unknown value     | Invalid for_each argument       | `set includes values derived from resource attributes that cannot be determined`        | CausedByUnknown                   |
      | StringSet with a Sensitive value    | Invalid for_each argument       | `Sensitive values, or values derived from sensitive values, cannot be used`             | CausedBySensitive                 |
      | StringSet with an Ephemeral value   | Invalid for_each argument       | `The given "for_each" value is derived from an ephemeral value`                         | CausedByEphemeral                 |

  Scenario Outline: Evaluating for_each expressions for resources with allowUnknown = true
    Given an HCL expression that evaluates to <CtyValueDescription>
    And allowUnknown is true for resource evaluation
    When evaluateForEachExpression is called
    Then <DiagnosticState>
    And the result known status should be <IsKnown>

    Examples:
      | CtyValueDescription             | DiagnosticState  | IsKnown |
      | Unknown StringSet               | no diagnostics   | false   |
      | Unknown Map (String to Bool)    | no diagnostics   | false   |
      | StringSet with an Unknown value | no diagnostics   | false   | # Because the set itself becomes unknown if elements are
      | Map: {"a":true}                 | no diagnostics   | true    |

  Scenario: Evaluating a nil expression for for_each (resource context)
    Given a nil HCL expression for for_each
    And allowUnknown is false for resource evaluation
    When evaluateForEachExpression is called
    Then the resulting for_each map should be empty
    And the result should be fully known
    And no diagnostics should be produced

  Scenario Outline: Evaluating for_each expressions for import blocks
    Given an HCL expression that evaluates to <CtyValueDescription> for an import block
    And allowUnknown is <AllowUnknownSetting> for import evaluation
    When the for_each evaluator's ImportValues method is called
    Then the resulting RepetitionData list should be <ExpectedRepetitionDataJSON>
    And <DiagnosticState>
    And the result known status should be <IsKnown>

    Examples:
      # CtyValueDescription, AllowUnknownSetting, ExpectedRepetitionDataJSON, DiagnosticState, IsKnown
      | List of Numbers [1, 2]        | false | '[{"key":0, "value":1}, {"key":1, "value":2}]' | no diagnostics | true  |
      | Map {"k1":"v1", "k2":"v2"}    | false | '[{"key":"k1", "value":"v1"}, {"key":"k2", "value":"v2"}]' | no diagnostics | true  | # Order may vary for map
      | StringSet ["a", "b"]          | false | '[{"key":"a", "value":"a"}, {"key":"b", "value":"b"}]' | no diagnostics | true  | # Order may vary for set
      | Null List(Number)             | false | '[]'                                           | no diagnostics | true  |
      | String "not_iterable"         | false | '[]'                                           | an error diagnostic occurs with summary "Invalid for_each argument" and detail "The \"for_each\" expression must be a collection." | false |
      | Unknown List(Number)          | false | '[]'                                           | an error diagnostic occurs with summary "Invalid for_each argument" and detail "The \\\"for_each\\\" expression includes values derived from other resource attributes" | false |
      | Unknown List(Number)          | true  | '[]'                                           | no diagnostics | false |
      | List [1] (marked Ephemeral)   | false | '[]'                                           | an error diagnostic occurs with summary "Invalid for_each argument" and detail "The given \\\"for_each\\\" value is derived from an ephemeral value" | true (but with error) |
      # Sensitive values in ImportValues are passed through with marks in RepetitionData.value

  Scenario: Evaluating a nil expression for for_each (import context)
    Given a nil HCL expression for for_each for an import block
    And allowUnknown is false for import evaluation
    When the for_each evaluator's ImportValues method is called
    Then the resulting RepetitionData list should be empty
    And no diagnostics should be produced
    And the result should be fully known

  Scenario Outline: Validating for_each expressions for resources (ValidateResourceValue method)
    Given an HCL expression that evaluates to <CtyValueDescription>
    When the for_each evaluator's ValidateResourceValue method is called
    Then <DiagnosticState>

    Examples:
      | CtyValueDescription          | DiagnosticState                                                                                                |
      | Unknown StringSet            | no diagnostics                                                                                                 | # Unknowns are allowed during validation phase
      | Unknown Map (String to Bool) | no diagnostics                                                                                                 |
      | Map (String to Bool) marked Sensitive | an error diagnostic occurs with summary "Invalid for_each argument" and detail "Sensitive values, or values derived from sensitive values, cannot be used" |
      | String "not_a_collection"    | an error diagnostic occurs with summary "Invalid for_each argument" and detail "must be a map, or set of strings"    |

  # Notes for step definitions:
  # - <ExpectedMapJSON> and <ExpectedRepetitionDataJSON> imply JSON string representations of the expected cty values or structures.
  # - <CtyValueDescription> needs to be parsed into actual cty.Value by step definitions (e.g., "Null StringSet", "Map: {\"a\":true}", "Unknown Map (String to Bool)").
  # - <CausedByFlags> indicates which tfdiags.DiagnosticCausedBy* function would return true for the diagnostic.
  # - "(unknown)", "(sensitive)" in ExpectedMapJSON are placeholders for how step defs might represent these values.
  # - The "for_each evaluator" would be instantiated by `newForEachEvaluator(expr, ctx, allowUnknown)` in step definitions.
