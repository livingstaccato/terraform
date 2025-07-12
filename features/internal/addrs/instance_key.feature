# Metadata:
# Covers: internal/addrs/instance_key_test.go
# TestFunctions:
# - TestInstanceKeyString

Feature: Instance Key String Representation
  This feature describes the expected string formatting for instance keys,
  which are used to identify specific instances of resources or modules
  when count or for_each is used.

  Scenario Outline: Formatting of Instance Keys
    Given an instance key of <KeyType> with value <KeyValue>
    When its string representation is generated
    Then the result should be "<ExpectedString>"

    Examples:
      | KeyType    | KeyValue    | ExpectedString        | Description                                   |
      | Integer    | 0           | [0]                   | Zero integer key                              |
      | Integer    | 5           | [5]                   | Positive integer key                          |
      | String     | ""          | [""]                  | Empty string key                              |
      | String     | "hi"        | ["hi"]                | Simple string key                             |
      | String     | "0"         | ["0"]                 | String key "0" (distinct from integer 0)      |
      | String     | "\""        | ["\""]                | String key with a quote                       |
      | String     | "\\r\\n"    | ["\\\\r\\\\n"]        | String key with escape sequences              |
      | String     | "${hello}"  | ["$${hello}"]         | String key with template interpolation        |
      | String     | "%{ for }"  | ["%%{ for }"]         | String key with template control sequence     |
      | String     | "$hello"    | ["$hello"]            | String key with dollar not needing escape     |
      | String     | "%hello"    | ["%hello"]            | String key with percent not needing escape    |

```

Notes on this Gherkin:

*   A `Scenario Outline` is used to cover the various test cases for `InstanceKey.String()`.
*   The `<KeyType>` helps differentiate between `IntKey` and `StringKey`.
*   The `<KeyValue>` column holds the raw value used to create the key.
*   The `<ExpectedString>` is the exact string output the test expects.
*   A `<Description>` column is added for better readability of the examples.
*   Special characters in the `KeyValue` and `ExpectedString` (like quotes and backslashes) are written as they appear in the Go test's `Want` field, which should be directly usable in Gherkin.

Next, I'll proceed to `internal/addrs/map_test.go`.
