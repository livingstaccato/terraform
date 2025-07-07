# Source Go File: internal/tfdiags/format.go
# Source Go Test: internal/tfdiags/format_test.go

Feature: Formatting cty.Value for Diagnostics
  Describes how cty.Value instances are formatted into strings for display
  in Terraform diagnostic messages, including compaction and redaction.

  Scenario Outline: Compacting cty.Value to a string summary
    Given a cty.Value of <Type> with value <LiteralValue>
    When CompactValueStr is called with this value
    Then the result should be "<ExpectedCompactString>"

    Examples:
      | Type                  | LiteralValue          | ExpectedCompactString            |
      | DynamicPseudoType     | null                  | null                             |
      | DynamicPseudoType     | unknown               | (not yet known)                  |
      | Bool                  | false                 | false                            |
      | Bool                  | true                  | true                             |
      | Number                | 5                     | 5                                |
      | Number                | 5.2                   | 5.2                              |
      | String                | ""                    | ""                               |
      | String                | "hello"               | "hello"                          |
      | List(String)          | []                    | empty list of string             |
      | Set(String)           | []                    | empty set of string              |
      | Tuple([])             | []                    | empty tuple                      |
      | Map(String)           | {}                    | empty map of string              |
      | Object({})            | {}                    | object with no attributes        |
      | List(String)          | ["a"]                 | list of string with 1 element    |
      | List(String)          | ["a", "b"]            | list of string with 2 elements   |
      | Object({a=String})    | {"a": "b"}            | object with 1 attribute "a"      |
      | Object({a=String,c=String}) | {"a": "b", "c": "d"} | object with 2 attributes         |

  Scenario Outline: Compacting cty.Value with marks
    Given a cty.StringValue "<OriginalString>"
    And the value is marked as <Mark>
    When CompactValueStr is called with this marked value
    Then the result should be "<ExpectedCompactString>"

    Examples:
      | OriginalString      | Mark      | ExpectedCompactString |
      | "a sensitive value" | Sensitive | (sensitive value)     |
      | "an ephemeral value"| Ephemeral | (ephemeral value)   |

  Scenario: Formatting a simple cty.Value to JSON compatible string
    Given a cty.ObjectValue with attributes:
      | key   | type   | value   |
      | "name"| String | "Terraform" |
      | "version"| Number | 1.0     |
    When FormatValueStr is called with this value
    Then the result should be a JSON string equivalent to:
    """
    {
      "name": "Terraform",
      "version": 1.0
    }
    """
    And the JSON string should be indented with 2 spaces

  Scenario: Formatting a cty.Value with sensitive data to JSON compatible string
    Given a cty.ObjectValue with attributes:
      | key       | type   | value        | sensitive |
      | "user"    | String | "admin"      | false     |
      | "password"| String | "s3cr3tP4ss" | true      |
    When FormatValueStr is called with this value
    Then the result should be a JSON string equivalent to:
    """
    {
      "user": "admin",
      "password": "(sensitive value)"
    }
    """
    And the JSON string should be indented with 2 spaces

  Scenario: Formatting a cty.Value with ephemeral data to JSON compatible string
    Given a cty.ObjectValue with attributes:
      | key       | type   | value        | ephemeral |
      | "id"      | String | "12345"      | false     |
      | "temp_key"| String | "temporary"  | true      |
    When FormatValueStr is called with this value
    Then the result should be a JSON string equivalent to:
    """
    {
      "id": "12345",
      "temp_key": "(ephemeral value)"
    }
    """
    And the JSON string should be indented with 2 spaces

  Scenario: Formatting a cty.Value with unknown data to JSON compatible string
    Given a cty.ObjectValue with attributes:
      | key     | type   | value        | known |
      | "name"  | String | "known"      | true  |
      | "future"| String | "value"      | false | # This will be represented as an unknown value
    When FormatValueStr is called with this value
    Then the result should be a JSON string equivalent to:
    """
    {
      "name": "known",
      "future": "(not yet known)"
    }
    """
    And the JSON string should be indented with 2 spaces

  Scenario: Formatting a cty.Value with nested sensitive data
    Given a cty.ObjectValue with a nested object "credentials":
      | path                  | type   | value        | sensitive |
      | "user"                | String | "testuser"   | false     |
      | "credentials.token"   | String | "secret-token" | true      |
      | "credentials.expiry"  | Number | 1678886400   | false     |
    When FormatValueStr is called with this value
    Then the result should be a JSON string equivalent to:
    """
    {
      "user": "testuser",
      "credentials": {
        "token": "(sensitive value)",
        "expiry": 1678886400
      }
    }
    """
    And the JSON string should be indented with 2 spaces

  Scenario: Formatting a cty.ListValue with some sensitive elements
    Given a cty.ListValue of strings: ["public", "verysecret", "internal"]
    And the second element "verysecret" is marked as sensitive
    When FormatValueStr is called with this value
    Then the result should be a JSON string equivalent to:
    """
    [
      "public",
      "(sensitive value)",
      "internal"
    ]
    """
    And the JSON string should be indented with 2 spaces
