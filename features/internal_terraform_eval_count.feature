# Source Go File: internal/terraform/eval_count.go
# Source Go Test: internal/terraform/eval_count_test.go

Feature: Evaluate Count Expression
  This feature describes how Terraform evaluates HCL expressions provided for "count"
  meta-arguments, including type checking, handling of unknown values, and special
  value markings like sensitive or ephemeral.

  Scenario Outline: Evaluating valid count expressions (allowUnknown = false)
    Given an HCL expression that evaluates to <CtyValueDescription>
    And allowUnknown is false
    When evaluateCountExpression is called
    Then the resulting count should be <ExpectedCount>
    And no diagnostics should be produced

    Examples:
      | CtyValueDescription             | ExpectedCount |
      | NumberValue 0                   | 0             |
      | NumberValue 5                   | 5             |
      | NumberValue 10 (marked Sensitive) | 10            |

  Scenario Outline: Evaluating count expressions with allowUnknown = true
    Given an HCL expression that evaluates to <CtyValueDescription>
    And allowUnknown is true
    When evaluateCountExpression is called
    Then the resulting count should be <ExpectedCount>
    And <DiagnosticState>

    Examples:
      | CtyValueDescription             | ExpectedCount | DiagnosticState             |
      | NumberValue 3                   | 3             | no diagnostics              |
      | UnknownNumberValue              | -1            | no diagnostics              | # Unknown allowed, returns -1
      | DynamicValue (resolves to Number 7 eventually) | -1            | no diagnostics              | # Dynamic treated as unknown if not resolved by EvaluateExpr
      | NullNumberValue                 | -1            | an error diagnostic occurs with summary "Invalid count argument" and detail 'The given "count" argument value is null. An integer is required.' |
      | NumberValue -2                  | -1            | an error diagnostic occurs with summary "Invalid count argument" and detail 'The given "count" argument value is unsuitable: must be greater than or equal to zero.' |
      | NumberValue 1 (marked Ephemeral)| -1            | an error diagnostic occurs with summary "Invalid count argument" and detail 'The given "count" value is derived from an ephemeral value, which means that Terraform cannot persist it between plan/apply rounds. Use only non-ephemeral values here.' |

  Scenario Outline: Evaluating invalid count expressions (allowUnknown = false)
    Given an HCL expression that evaluates to <CtyValueDescription>
    And allowUnknown is false
    When evaluateCountExpression is called
    Then an error diagnostic should occur with summary "Invalid count argument"
    And the diagnostic detail should contain "<ExpectedDetailSubstring>"
    # And the resulting count may be -1 or an undefined default depending on error type

    Examples:
      | CtyValueDescription             | ExpectedDetailSubstring                                                                                                |
      | NullNumberValue                 | 'The given "count" argument value is null. An integer is required.'                                                    |
      | NumberValue -1                  | 'The given "count" argument value is unsuitable: must be greater than or equal to zero.'                               |
      | NumberValue 3 (marked Ephemeral)| 'The given "count" value is derived from an ephemeral value, which means that Terraform cannot persist it between plan/apply rounds. Use only non-ephemeral values here.' |
      | UnknownNumberValue              | 'The "count" value depends on resource attributes that cannot be determined until apply, so Terraform cannot predict how many instances will be created.' |
      | StringValue "not-a-number"      | 'The given "count" argument value is unsuitable: cty: cannot convert string "not-a-number" to number'                | # Assuming EvaluateExpr ensures number type, else gocty.FromCtyValue error
      | BoolValue true                  | 'The given "count" argument value is unsuitable: cty: cannot convert bool true to number'                            | # Assuming EvaluateExpr ensures number type, else gocty.FromCtyValue error

  Scenario: Evaluating a nil expression for count
    Given a nil HCL expression for count
    And allowUnknown is false (or true, behavior should be similar for nil expr)
    When evaluateCountExpression is called
    # evaluateCountExpressionValue returns NullVal for nil expr, then evaluateCountExpression processes it.
    Then an error diagnostic should occur with summary "Invalid count argument"
    And the diagnostic detail should contain 'The given "count" argument value is null. An integer is required.'
    And the resulting count should be -1

  # Note on "DynamicValue (resolves to Number 7 eventually)":
  # The evaluateCountExpression function itself doesn't resolve DynamicVal if EvaluateExpr passes it through.
  # If EvaluateExpr returns an UnknownVal(Number) for a DynamicVal it can't resolve, then it's handled as Unknown.
  # If EvaluateExpr *were* to return a known DynamicVal (which is unusual for this context), gocty.FromCtyValue would error.
  # The example assumes it's treated as unknown if not resolved by EvaluateExpr.

  # Note on "StringValue "not-a-number"" and "BoolValue true":
  # The function evaluateCountExpressionValue calls ctx.EvaluateExpr(expr, cty.Number, nil).
  # This requests a cty.Number. If EvaluateExpr successfully converts/coerces to Number (e.g. "123" -> 123), fine.
  # If it cannot (e.g. "abc" -> Number), EvaluateExpr itself should produce diags.
  # If EvaluateExpr *does* return a non-Number type despite the request (bad mock/impl), then gocty.FromCtyValue in evaluateCountExpressionValue would produce the cty conversion error.
  # The BDD assumes gocty.FromCtyValue is the one producing the specific error message if type mismatch occurs post EvaluateExpr.
