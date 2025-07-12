# Metadata:
# Covers: internal/backend/backendbase/helper_test.go
# TestFunctions:
# - TestGetPathDefault
# - TestGetAttrDefault
# - TestGetPathEnvDefault (which implicitly covers GetAttrEnvDefault)

Feature: Backend Configuration Helper Utilities
  This feature describes helper utilities used for retrieving values from
  backend configurations, with support for default values and environment variable fallbacks.

  Scenario Outline: Get Value by Path with Default
    Given a cty object with value <InitialObjectValueString>
    And a cty path expression "<PathExpression>" targeting an attribute of type <AttributeTypeString>
    And a default cty value <DefaultValueString> of type <AttributeTypeString>
    When I get the value at the path with the specified default
    Then the result should be <ExpectedValueString> of type <AttributeTypeString>

    Examples:
      | InitialObjectValueString | PathExpression | AttributeTypeString | DefaultValueString | ExpectedValueString | Description                     |
      | `{"a": "a value"}`       | "a"            | String              | "default"          | "a value"           | Attribute is set                |
      | `{"a": null}`            | "a"            | String              | "default"          | "default"           | Attribute is null, default used |
      | `{}`                     | "b"            | String              | "default_b"        | "default_b"         | Attribute not present, default used |

  Scenario Outline: Get Value by Attribute Name with Default
    Given a cty object with value <InitialObjectValueString>
    And an attribute name "<AttributeName>" of type <AttributeTypeString>
    And a default cty value <DefaultValueString> of type <AttributeTypeString>
    When I get the value of the attribute with the specified default
    Then the result should be <ExpectedValueString> of type <AttributeTypeString>

    Examples:
      | InitialObjectValueString | AttributeName | AttributeTypeString | DefaultValueString | ExpectedValueString | Description                     |
      | `{"a": "a value"}`       | "a"           | String              | "default"          | "a value"           | Attribute is set                |
      | `{"a": null}`            | "a"           | String              | "default"          | "default"           | Attribute is null, default used |
      | `{}`                     | "b"           | String              | "default_b"        | "default_b"         | Attribute not present, default used |

  Scenario Outline: Get Value by Path/Attribute with Environment Variable Fallback
    Given a cty object with value <InitialObjectValueString>
    And an attribute name "<AttributeName>" (for path and attr access) of type <AttributeTypeString>
    And an environment variable "<EnvVarName>" is set to "<EnvVarValue>"
    When I get the value of the attribute falling back to the environment variable "<EnvVarName>"
    Then the result using GetAttrEnvDefault should be <ExpectedValueString> of type <AttributeTypeString>
    And the result using GetPathEnvDefault (with path for "<AttributeName>") should be <ExpectedValueString> of type <AttributeTypeString>

    Examples:
      | InitialObjectValueString | AttributeName | AttributeTypeString | EnvVarName            | EnvVarValue | ExpectedValueString | Description                                     |
      | `{"a": "a value"}`       | "a"           | String              | DEFAULT_VALUE_SET     | "default"   | "a value"           | Attribute is set, env var ignored               |
      | `{"a": null}`            | "a"           | String              | DEFAULT_VALUE_SET     | "default"   | "default"           | Attribute null, env var used                    |
      | `{"a": null}`            | "a"           | String              | DEFAULT_VALUE_UNSET   | (unset)     | null                | Attribute null, env var unset, result null      |
      | `{"a": null}`            | "a"           | String              | DEFAULT_VALUE_EMPTY   | ""          | null                | Attribute null, env var empty, result null      |
      | `{"b": "b value"}`       | "a"           | String              | DEFAULT_VALUE_SET     | "default"   | "default"           | Attribute 'a' not present, env var used         |

  Scenario Outline: Get Value by Path/Attribute with Environment Variable and Static Fallback
    Given a cty object with value <InitialObjectValueString>
    And an attribute name "<AttributeName>" (for path and attr access) of type <AttributeTypeString>
    And an environment variable "<EnvVarName>" is set to "<EnvVarValue>"
    And a static fallback cty value <FallbackValueString> of type <AttributeTypeString>
    When I get the value of the attribute falling back to environment variable "<EnvVarName>" and then to static fallback
    Then the result using GetAttrEnvDefaultFallback should be <ExpectedValueString> of type <AttributeTypeString>
    And the result using GetPathEnvDefaultFallback (with path for "<AttributeName>") should be <ExpectedValueString> of type <AttributeTypeString>

    Examples:
      | InitialObjectValueString | AttributeName | AttributeTypeString | EnvVarName            | EnvVarValue | FallbackValueString | ExpectedValueString | Description                                          |
      | `{"a": "a value"}`       | "a"           | String              | DEFAULT_VALUE_SET     | "default"   | "static_fallback"   | "a value"           | Attribute is set, env and static fallback ignored    |
      | `{"a": null}`            | "a"           | String              | DEFAULT_VALUE_SET     | "default"   | "static_fallback"   | "default"           | Attribute null, env var used, static fallback ignored|
      | `{"a": null}`            | "a"           | String              | DEFAULT_VALUE_UNSET   | (unset)     | "static_fallback"   | "static_fallback"   | Attribute null, env var unset, static fallback used  |
      | `{"a": null}`            | "a"           | String              | DEFAULT_VALUE_EMPTY   | ""          | "static_fallback"   | "static_fallback"   | Attribute null, env var empty, static fallback used  |
      | `{"a": null}`            | "a"           | String              | DEFAULT_VALUE_UNSET   | (unset)     | null                | null                | All fallbacks exhausted, result null (if fallback is null) |
      | `{"b": "b value"}`       | "a"           | String              | DEFAULT_VALUE_SET     | "default"   | "static_fallback"   | "default"           | Attribute 'a' not present, env var used            |
      | `{"b": "b value"}`       | "a"           | String              | DEFAULT_VALUE_UNSET   | (unset)     | "static_fallback"   | "static_fallback"   | Attribute 'a' not present, env unset, static used  |

  Scenario Outline: Converting cty.Value to Int64
    Given a cty value <CtyValueString> of type <ValueTypeString>
    When I convert it to an Int64 using IntValue
    Then the result should be <ExpectedInt>
    And if an error is expected, it should contain "<ExpectedError>"

    Examples:
      | CtyValueString | ValueTypeString | ExpectedInt | ExpectedError                      | Description                       |
      | "123"          | String          | 123         |                                    | Valid string integer              |
      | 456            | Number          | 456         |                                    | Valid number integer              |
      | "abc"          | String          | 0           | "invalid syntax"                   | Invalid string integer            |
      | 10.5           | Number          | 0           | "must not be a whole number"       | Number with fraction              |
      | null           | Number          | 0           | "must not be null"                 | Null number                       |
      | true           | Bool            | 0           | "cannot convert True to cty.Number"| Bool to number conversion error |

  Scenario Outline: Converting cty.Value to Bool
    Given a cty value <CtyValueString> of type <ValueTypeString>
    When I convert it to a Bool using BoolValue
    Then the result should be <ExpectedBool>
    And if an error is expected, it should contain "<ExpectedError>"

    Examples:
      | CtyValueString | ValueTypeString | ExpectedBool | ExpectedError                       | Description                     |
      | "true"         | String          | true         |                                     | Valid string "true"             |
      | "false"        | String          | false        |                                     | Valid string "false"            |
      | true           | Bool            | true         |                                     | Valid bool true                 |
      | false          | Bool            | false        |                                     | Valid bool false                |
      | "yes"          | String          | false        | "invalid syntax"                    | Invalid string for bool         |
      | null           | Bool            | false        | "must not be null"                  | Null bool                       |
      | 1              | Number          | false        | "cannot convert Number to cty.Bool" | Number to bool conversion error |

```

Notes for this Gherkin:
*   I've used `<InitialObjectValueString>`, `<DefaultValueString>`, `<ExpectedValueString>` and specified `<AttributeTypeString>` to allow step definitions to parse these into actual `cty.Value` objects. For example, `{"a": "a value"}` would become `cty.ObjectVal(map[string]cty.Value{"a": cty.StringVal("a value")})`. `null` would become `cty.NullVal(cty.String)`.
*   The `GetPathEnvDefault` scenario combines testing both `GetAttrEnvDefault` and `GetPathEnvDefault` as the Go test does, because their core logic is similar.
*   The environment variable setup (`<EnvVarValue>` being `(unset)` or `""`) is handled in the examples.
*   The descriptions help clarify each test case's intent.

Next, I'll process `internal/backend/backendbase/sdklike_test.go`.
