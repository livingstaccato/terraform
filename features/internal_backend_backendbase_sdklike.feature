# Source Go File: internal/backend/backendbase/sdklike.go
# Source Go Test: internal/backend/backendbase/sdklike_test.go

Feature: SDK-Like Backend Configuration Helpers
  This feature describes helper functions that mimic the behavior of the legacy
  Terraform SDK for accessing and defaulting backend configuration values. This
  includes path creation, environment variable fallbacks, and type-specific getters.

  Background:
    Given the SDK-like backend configuration helper context

  Scenario Outline: Creating a cty.Path from an SDK-like string path
    Given an SDK-like path string "<PathString>"
      # e.g., "foo", "foo.bar"
    When SDKLikePath is called with this string
    Then the result should be a cty.Path equivalent to <ExpectedCtyPathStepsJSON>
      # e.g., '[{"type":"GetAttr","name":"foo"}]'

    Examples:
      | PathString  | ExpectedCtyPathStepsJSON                                           |
      | "foo"       | "[{\"type\":\"GetAttr\",\"name\":\"foo\"}]"                         |
      | "foo.bar"   | "[{\"type\":\"GetAttr\",\"name\":\"foo\"},{\"type\":\"GetAttr\",\"name\":\"bar\"}]" |
      | "foo.bar.baz" | "[{\"type\":\"GetAttr\",\"name\":\"foo\"},{\"type\":\"GetAttr\",\"name\":\"bar\"},{\"type\":\"GetAttr\",\"name\":\"baz\"}]" |

  Scenario Outline: Getting a string value with environment variable fallbacks
    Given an initial string value "<InitialValue>"
    And a list of environment variable names for fallback: <EnvVarNamesListJSON>
      # e.g., '["FALLBACK_A", "FALLBACK_B"]'
    And the following environment variables are set: <EnvVarsSetup>
      # e.g., "FALLBACK_A=val_a, FALLBACK_B=val_b" or "FALLBACK_A is unset"
    When SDKLikeEnvDefault is called with the initial value and environment variable names
    Then the result should be the string "<ExpectedStringValue>"

    Examples:
      | InitialValue | EnvVarNamesListJSON              | EnvVarsSetup                                  | ExpectedStringValue |
      | "hello"      | "[\"FALLBACK_A\", \"FALLBACK_B\"]" | "FALLBACK_A=val_a, FALLBACK_B=val_b"          | "hello"             | # Initial value is used
      | ""           | "[\"FALLBACK_A\", \"FALLBACK_B\"]" | "FALLBACK_A=val_a, FALLBACK_B=val_b"          | "val_a"             | # First env var fallback
      | ""           | "[\"FALLBACK_X\", \"FALLBACK_B\"]" | "FALLBACK_X is unset, FALLBACK_B=val_b"       | "val_b"             | # Second env var fallback
      | ""           | "[\"FALLBACK_X\", \"FALLBACK_Y\"]" | "FALLBACK_X is unset, FALLBACK_Y is unset"    | ""                  | # No fallbacks, empty string
      | ""           | "[\"FALLBACK_EMPTY\", \"FALLBACK_B\"]" | "FALLBACK_EMPTY=, FALLBACK_B=val_b"       | "val_b"             | # Empty env var is skipped

  Scenario: Requiring a string value with environment variable fallback (error case)
    Given an attribute name "attr_name"
    And an initial empty string value ""
    And an environment variable "FALLBACK_UNSET" is not set (or empty)
    When SDKLikeRequiredWithEnvDefault is called with the attribute name, initial value, and "FALLBACK_UNSET"
    Then an error should occur with the message "attribute \"attr_name\" is required"

  Scenario: Applying SDKLikeDefaults to a cty.ObjectVal configuration
    Given an SDKLikeDefaults map:
      | Key                   | FallbackValue        | EnvVars (JSON list)                |
      | "string_set_fallback" | "fallback not used"  | []                                 |
      | "string_set_env"      | null                 | "[\"FALLBACK_UNUSED_ENV\"]"        |
      | "string_fallback_null"| "boop from fallback" | []                                 |
      | "string_env_null"     | "unused_fallback"    | "[\"ENV_BEEP\", \"ENV_UNUSED\"]"   |
      | "string_nothing_null" | null                 | "[\"ENV_EMPTY\"]"                  |
    And environment variables are set: "ENV_BEEP=beep from environment", "ENV_EMPTY=" (empty)
    And an input cty.ObjectVal configuration:
      {
        "string_set_fallback": StringVal("set in config"),
        "string_set_env": StringVal("set in config"),
        "string_fallback_null": NullVal(String),
        "string_env_null": NullVal(String),
        "string_nothing_null": NullVal(String),
        "passthru_attr": EmptyObjectVal
      }
    When ApplyTo is called on the SDKLikeDefaults with the input configuration
    Then the resulting cty.ObjectVal should be equivalent to:
      {
        "string_set_fallback": StringVal("set in config"),        # Took input value
        "string_set_env": StringVal("set in config"),           # Took input value
        "string_fallback_null": StringVal("boop from fallback"), # Took fallback
        "string_env_null": StringVal("beep from environment"),  # Took ENV_BEEP
        "string_nothing_null": NullVal(String),                 # Remained null (empty ENV_EMPTY)
        "passthru_attr": EmptyObjectVal                         # Passed through
      }
    And no error should occur

  Scenario Outline: Using SDKLikeData to get typed values from a cty.ObjectVal
    Given an SDKLikeData initialized with cty.ObjectVal <ConfigJSON>
    When <GetterMethod> is called with attribute name "<AttributeName>"
    Then the result should be <ExpectedResult>
    And if an error is expected, the error message should contain "<ExpectedErrorHint>"

    Examples:
      | ConfigJSON                                                                                                   | GetterMethod | AttributeName | ExpectedResult          | ExpectedErrorHint |
      | "{\"str\":\"hello\",\"num\":5,\"bool\":true,\"null_str\":null,\"null_num\":null,\"null_bool\":null,\"float_num\":0.5}" | String       | "str"         | "hello"                 |                   |
      | "{\"str\":\"hello\",\"num\":5,\"bool\":true,\"null_str\":null,\"null_num\":null,\"null_bool\":null,\"float_num\":0.5}" | String       | "null_str"    | ""                      |                   | # Null string becomes empty
      | "{\"str\":\"hello\",\"num\":5,\"bool\":true,\"null_str\":null,\"null_num\":null,\"null_bool\":null,\"float_num\":0.5}" | String       | "num"         | "5"                     |                   | # Number to string
      | "{\"str\":\"hello\",\"num\":5,\"bool\":true,\"null_str\":null,\"null_num\":null,\"null_bool\":null,\"float_num\":0.5}" | String       | "bool"        | "true"                  |                   | # Bool to string
      | "{\"str\":\"hello\",\"num\":5,\"bool\":true,\"null_str\":null,\"null_num\":null,\"null_bool\":null,\"float_num\":0.5}" | Int64        | "num"         | 5L                      |                   |
      | "{\"str\":\"hello\",\"num\":5,\"bool\":true,\"null_str\":null,\"null_num\":null,\"null_bool\":null,\"float_num\":0.5}" | Int64        | "float_num"   | error                   | "invalid syntax"  | # Float to Int64 error
      | "{\"str\":\"hello\",\"num\":5,\"bool\":true,\"null_str\":null,\"null_num\":null,\"null_bool\":null,\"float_num\":0.5}" | Int64        | "null_num"    | 0L                      |                   | # Null number becomes 0
      | "{\"str\":\"hello\",\"num\":5,\"bool\":true,\"null_str\":null,\"null_num\":null,\"null_bool\":null,\"float_num\":0.5}" | Bool         | "bool"        | true                    |                   |
      | "{\"str\":\"hello\",\"num\":5,\"bool\":true,\"null_str\":null,\"null_num\":null,\"null_bool\":null,\"float_num\":0.5}" | Bool         | "null_bool"   | false                   |                   | # Null bool becomes false

  # Note:
  # - SDKLikePath creates a cty.Path consisting only of GetAttrSteps.
  # - SDKLikeEnvDefault prioritizes the initial value, then environment variables in order, then returns empty/zero if none found.
  # - SDKLikeData provides typed getters (String, Int64, Bool) that attempt cty conversions if types don't match directly.
  # - These helpers are cty-aware and used for backend configurations which are cty.Value.
  # - Step definitions need to parse JSON into cty.Value, cty.Path, and lists of strings.
  # - Environment variable setup/teardown is crucial for SDKLikeEnvDefault tests.
  # - For SDKLikeData, "5L" indicates a Go int64.
  # - "error" in ExpectedResult means an error is expected from the getter.
