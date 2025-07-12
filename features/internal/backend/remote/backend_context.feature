# Metadata:
# Covers: internal/backend/remote/backend_context_test.go
# TestFunctions:
# - TestRemoteStoredVariableValue
# - TestRemoteContextWithVars
# - TestRemoteVariablesDoNotOverride

Feature: Remote Backend Context Preparation with Variables
  This feature describes how the remote backend (Terraform Cloud/Enterprise)
  prepares the execution context, focusing on how it handles variables
  defined in the remote workspace and their interaction with local configurations.

  Scenario Outline: Parsing Stored Variable Values from Remote Backend
    Given a variable "test" fetched from the remote backend with value "<Value>", HCL flag <IsHCL>, and sensitive flag <IsSensitive>
    When its value is parsed for the Terraform context
    Then the resulting cty.Value should be <ExpectedCtyValue> (type: <ExpectedCtyType>)
    And if an error is expected, it should contain "<ExpectedErrorMessage>"

    Examples:
      | Value                | IsHCL | IsSensitive | ExpectedCtyValue | ExpectedCtyType     | ExpectedErrorMessage |
      | foo                  | false | false       | "foo"            | String              |                      |
      | "\"foo\""            | true  | false       | "foo"            | String              |                      |
      | "[]"                 | true  | false       | []               | EmptyTuple          |                      |
      | "null"               | true  | false       | null             | DynamicPseudoType   |                      |
      | (any)                | false | true        | (Unknown)        | String              |                      | # Literal sensitive is unknown string
      | (any)                | true  | true        | (Dynamic)        | DynamicPseudoType   |                      | # HCL sensitive is dynamic
      | "[for v in [\"a\"] : v]" | true  | false   | ["a"]            | Tuple(String)       |                      | # HCL computation
      | "["                  | true  | false       | (Dynamic)        | DynamicPseudoType   | "Invalid expression for var.test" | # HCL syntax error
      | "foo.bar"            | true  | false       | (Dynamic)        | DynamicPseudoType   | "Invalid expression for var.test" | # HCL with references

  Scenario Outline: Handling Undeclared Variables from Remote Backend During Context Preparation
    Given an empty local configuration
    And a remote workspace for the "default" state
    And a variable "key" with value "value" is stored in the remote workspace with category "<VariableCategory>"
    When the remote backend prepares the local run context for the "default" workspace
    Then the operation should <Outcome>
    And if it fails, an error diagnostic should be produced containing "<ExpectedErrorMessage>"
    And the remote state lock should be <LockState>

    Examples:
      | VariableCategory | Outcome | ExpectedErrorMessage                                                                | LockState |
      | Terraform        | fail    | 'Value for undeclared variable: A variable named "key" was assigned a value'        | unlocked  |
      | Environment      | succeed |                                                                                     | locked    |

  Scenario: Local Variables Override Remote Variables During Context Preparation
    Given a local configuration declaring variables "key1", "key2", "key3" (all strings)
    And a remote workspace for the "default" state
    And the following variables are stored in the remote workspace (all category "Terraform"):
      | Key    | Value    |
      | key1   | "remote_val1" |
      | key2   | "remote_val2" |
    And the following unparsed local variables are provided:
      | Key    | Value         | Source             |
      | key2   | "local_val2"  | "fake.tfvars:1,1"  |
      | key3   | "local_val3"  | "fake.tfvars:1,1"  |
    When the remote backend prepares the local run context for the "default" workspace with these local variables
    Then no error diagnostics should be produced
    And the prepared input variables for the plan should be:
      | Name   | Value         | SourceType         |
      | key1   | "remote_val1" | ValueFromInput     | # From remote
      | key2   | "local_val2"  | ValueFromNamedFile | # Local overrides remote
      | key3   | "local_val3"  | ValueFromNamedFile | # Only local
    And the remote state lock should be locked

```

Notes:
*   For `TestRemoteStoredVariableValue`:
    *   `<Value>` is the raw string value from TFE.
    *   `<IsHCL>` and `<IsSensitive>` map to `tfe.Variable` flags.
    *   `<ExpectedCtyValue>` uses string/JSON-like representations for cty values (e.g., `"foo"`, `[]`, `null`, `(Unknown)`, `(Dynamic)`).
    *   `<ExpectedCtyType>` helps clarify the type of the resulting cty.Value.
*   For `TestRemoteContextWithVars`:
    *   Focuses on whether undeclared TFE variables cause errors based on their category.
*   For `TestRemoteVariablesDoNotOverride`:
    *   Sets up both remote and local variables to test precedence.
    *   The `SourceType` in the expected plan variables indicates origin (`ValueFromInput` for remote TFE vars, `ValueFromNamedFile` for local vars in this test).

This covers the core logic of `backend_context_test.go`.

Next is `internal/backend/remote/backend_plan_test.go`.
