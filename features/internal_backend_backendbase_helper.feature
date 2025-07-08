# Source Go File: internal/backend/backendbase/helper.go
# Source Go Test: internal/backend/backendbase/helper_test.go

Feature: Backend Configuration Helper Functions
  This feature describes helper functions for retrieving values from backend
  configurations (represented as cty.Value objects), with support for default
  values and environment variable fallbacks.

  Background:
    Given the backend configuration helper context

  Scenario Outline: Getting a value by cty.Path with a default
    Given a cty.Value representing the configuration <ConfigValueJSON>
    And a cty.Path defined by steps <PathStepsJSON>
    And a default cty.Value <DefaultValueJSON>
    When GetPathDefault is called with the configuration, path, and default
    Then the result should be a cty.Value equivalent to <ExpectedValueJSON>

    Examples:
      | ConfigValueJSON                       | PathStepsJSON                                  | DefaultValueJSON | ExpectedValueJSON |
      | "{\"a\":\"a value\"}"                 | "[{\"type\":\"GetAttr\",\"name\":\"a\"}]"       | "\"default\""    | "\"a value\""     | # Attribute is set
      | "{\"a\":null}"                        | "[{\"type\":\"GetAttr\",\"name\":\"a\"}]"       | "\"default\""    | "\"default\""     | # Attribute is null, default used
      | "{\"b\":\"b value\"}"                 | "[{\"type\":\"GetAttr\",\"name\":\"a\"}]"       | "\"default\""    | "\"default\""     | # Attribute not present, default used
      | "{\"nested\":{\"attr\":\"nested_val\"}}" | "[{\"type\":\"GetAttr\",\"name\":\"nested\"},{\"type\":\"GetAttr\",\"name\":\"attr\"}]" | "\"def\"" | "\"nested_val\""  | # Nested attribute set
      | "{\"nested\":null}"                   | "[{\"type\":\"GetAttr\",\"name\":\"nested\"},{\"type\":\"GetAttr\",\"name\":\"attr\"}]" | "\"def\"" | "\"def\""         | # Nested attribute path evaluates to null, default used

  Scenario Outline: Getting an attribute value by name with a default
    Given a cty.Value representing the configuration <ConfigValueJSON>
    And an attribute name "<AttributeName>"
    And a default cty.Value <DefaultValueJSON>
    When GetAttrDefault is called with the configuration, attribute name, and default
    Then the result should be a cty.Value equivalent to <ExpectedValueJSON>

    Examples:
      | ConfigValueJSON       | AttributeName | DefaultValueJSON | ExpectedValueJSON |
      | "{\"a\":\"a value\"}" | "a"           | "\"default\""    | "\"a value\""     | # Attribute is set
      | "{\"a\":null}"        | "a"           | "\"default\""    | "\"default\""     | # Attribute is null, default used
      | "{\"b\":\"b value\"}" | "a"           | "\"default\""    | "\"default\""     | # Attribute not present, default used

  Scenario Outline: Getting an attribute value by name with environment variable fallback
    Given a cty.Value representing the configuration <ConfigValueJSON>
    And an attribute name "<AttributeName>"
    And an environment variable named "<EnvVarName>" is <EnvVarState>
      # EnvVarState can be "set to 'env_val'", "set to '' (empty string)", "not set"
    When GetAttrEnvDefault is called with the configuration, attribute name, and environment variable name
    Then the result should be a cty.Value equivalent to <ExpectedValueJSON>

    Examples:
      | ConfigValueJSON       | AttributeName | EnvVarName            | EnvVarState             | ExpectedValueJSON |
      | "{\"a\":\"a value\"}" | "a"           | "TEST_DEFAULT_VALUE"  | "set to 'env_val'"      | "\"a value\""     | # Attribute is set, env var ignored
      | "{\"a\":null}"        | "a"           | "TEST_DEFAULT_VALUE"  | "set to 'env_val'"      | "\"env_val\""     | # Attribute is null, env var used
      | "{\"a\":null}"        | "a"           | "TEST_DEFAULT_VALUE"  | "not set"               | "null"            | # Attribute null, env var not set, result is null
      | "{\"a\":null}"        | "a"           | "TEST_DEFAULT_EMPTY"  | "set to ''"             | "null"            | # Attribute null, env var empty, result is null
      | "{\"b\":\"val\"}"     | "a"           | "TEST_DEFAULT_VALUE"  | "set to 'env_val'"      | "\"env_val\""     | # Attribute not present, env var used

  Scenario Outline: Getting a value by cty.Path with environment variable fallback
    Given a cty.Value representing the configuration <ConfigValueJSON>
    And a cty.Path defined by attribute name "<AttributeName>"
    And an environment variable named "<EnvVarName>" is <EnvVarState>
    When GetPathEnvDefault is called with the configuration, path, and environment variable name
    Then the result should be a cty.Value equivalent to <ExpectedValueJSON>
    # This reuses the logic of GetAttrEnvDefault, so examples are similar

    Examples:
      | ConfigValueJSON       | AttributeName | EnvVarName            | EnvVarState             | ExpectedValueJSON |
      | "{\"a\":\"a value\"}" | "a"           | "TEST_DEFAULT_VALUE"  | "set to 'env_val'"      | "\"a value\""     |
      | "{\"a\":null}"        | "a"           | "TEST_DEFAULT_VALUE"  | "set to 'env_val'"      | "\"env_val\""     |

  # Note:
  # - Step definitions will need to parse JSON strings into cty.Value and cty.Path objects.
  # - Environment variable state needs to be managed by the test setup (e.g., t.Setenv in Go tests).
  # - The core cty interactions are Path.Apply for GetPathDefault, and direct attribute access combined
  #   with type checks (IsNull) for the others.
  # - ExpectedValueJSON "null" implies cty.NullVal of the appropriate type (e.g., cty.String for string attributes).
  # - The tests for GetPathDefault are not exhaustive for all cty.Path possibilities, as they delegate to cty.Path.Apply.
  #   The BDD focuses on the defaulting logic.
