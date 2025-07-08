# Source Go File: internal/backend/backendrun/unparsed_value.go
# Source Go Test: internal/backend/backendrun/unparsed_value_test.go

Feature: Parsing Unparsed Variable Values for Backend Runs
  This feature describes how Terraform parses a map of unparsed variable values
  (UnparsedVariableValue) against a set of declared variables (configs.Variable),
  separating them into declared and undeclared values, and producing diagnostics
  for undeclared variables or missing required declared variables.

  Background:
    Given a map of UnparsedVariableValue items, where each can be parsed into a terraform.InputValue (cty.Value with source info)
    And a map of declared configs.Variable definitions, including types, defaults, and parsing modes

  Scenario: Parsing only declared variable values
    Given unparsed values: {"declared1": "val_D1", "undeclared0": "val_U0"}
    And declared variables:
      | Name      | Type   | ParsingMode          | Default |
      | declared1 | String | VariableParseLiteral |         |
      | missing1  | String | VariableParseLiteral |         |
    When ParseDeclaredVariableValues is called
    Then the resulting terraform.InputValues map should contain:
      | Name      | Value        | SourceType         |
      | declared1 | "val_D1"     | ValueFromNamedFile |
    And the map should not contain "undeclared0" or "missing1"
    And no diagnostics should be produced

  Scenario: Parsing only undeclared variable values
    Given unparsed values: {"declared1": "val_D1", "undeclared0": "val_U0", "undeclared1": "val_U1"}
    And declared variables:
      | Name      | Type   | ParsingMode          |
      | declared1 | String | VariableParseLiteral |
    When ParseUndeclaredVariableValues is called
    Then the resulting terraform.InputValues map should contain:
      | Name        | Value    | SourceType         |
      | undeclared0 | "val_U0" | ValueFromNamedFile |
      | undeclared1 | "val_U1" | ValueFromNamedFile |
    And the map should not contain "declared1"
    And diagnostics should be produced for "undeclared0" with summary "Value for undeclared variable"
    And diagnostics should be produced for "undeclared1" with summary "Value for undeclared variable"
      # Note: The Go test shows multiple individual "Value for undeclared variable" diagnostics,
      # then a final "Values for undeclared variables" that groups further ones.
      # This BDD simplifies to check for the presence of undeclared variable diagnostics.

  Scenario: Parsing all variable values (declared, undeclared, and missing with/without defaults)
    Given unparsed values:
      | Name        | Value  |
      | declared1   | "val_D1" |
      | undeclared0 | "val_U0" |
    And declared variables:
      | Name      | Type   | ParsingMode          | DefaultValue         |
      | declared1 | String | VariableParseLiteral |                      |
      | missing1  | String | VariableParseLiteral |                      | # Required, no default, not in unparsed
      | missing2  | String | VariableParseLiteral | "default_for_missing2" | # Has default, not in unparsed
    When ParseVariableValues is called
    Then the resulting terraform.InputValues map should contain:
      | Name      | Value                  | SourceType         |
      | declared1 | "val_D1"               | ValueFromNamedFile |
      | missing1  | cty.DynamicVal         | ValueFromConfig    | # Becomes DynamicVal if required and missing
      | missing2  | cty.NullVal(cty.String)| ValueFromConfig    | # Becomes NullVal, core handles default
      # Undeclared values are not part of the primary result of ParseVariableValues, only diagnostics are generated for them.
    And diagnostics should be produced for "undeclared0" with summary "Value for undeclared variable"
    And diagnostics should be produced for "missing1" with summary "No value for required variable"
    And no diagnostic should be produced for "missing2" (as it has a default)

  # Note:
  # - UnparsedVariableValue is an interface with a ParseVariableValue method. For tests, a mock implementation is used.
  # - terraform.InputValue includes the cty.Value, SourceType (e.g., ValueFromNamedFile, ValueFromConfig), and SourceRange.
  # - The cty.Value parsing itself (string to cty.StringVal, etc.) is handled by the mock ParseVariableValue implementation.
  # - This feature focuses on the logic of distributing unparsed values based on declarations and generating appropriate diagnostics.
  # - SourceRange in the resulting InputValue is set based on the UnparsedVariableValue or the variable declaration.
  # - `ValueFromConfig` with `cty.NilVal` for `missing2` indicates that Terraform core will later substitute the default.
  # - `ValueFromConfig` with `cty.DynamicVal` for `missing1` indicates it's required but not provided.
  # - The exact grouping of "undeclared variable" diagnostics might vary (singular vs plural summary).
  #   The key is that undeclared variables are flagged.
