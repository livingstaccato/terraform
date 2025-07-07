# Covers robustness of deserialization against malformed or mismatched data.
# Inspired by general best practices for testing deserializers.
Feature: Wire Format Deserialization Error Handling and Edge Cases

  Background:
    Given a Terraform schema for an attribute

  Scenario Outline: Deserialize Malformed MessagePack <Description>
    Given the schema expects a "<TerraformType>"
    And an invalid MessagePack byte stream <MalformedMsgPackHex> representing "<Description>"
    When the MessagePack stream is deserialized according to the schema
    Then a deserialization error should occur indicating "<ExpectedErrorHint>"

    Examples:
      | Description                     | TerraformType      | MalformedMsgPackHex | ExpectedErrorHint                               |
      | Truncated String                | "string"           | "a568656c"          | "incomplete MessagePack data"                   | # "hello" -> "hel" with len 5
      | Truncated Map                   | ["map", "string"]  | "81a16b"            | "incomplete MessagePack data"                   | # {"k": ...} (value missing)
      | Invalid Map Key (Not String)    | ["map", "string"]  | "8101a176"          | "map key not a string"                          | # {1: "v"}
      | Array Length Exceeds Data       | ["list", "string"] | "92a161"            | "array contents shorter than length"            | # Array of 2, only one element "a"
      | String Instead of Number        | "number"           | "a3616263"          | "type mismatch"                                 | # "abc" for a number
      | Number Instead of String        | "string"           | "0a"                | "type mismatch"                                 | # 10 for a string
      | Invalid UTF-8 in String         | "string"           | "a4feff6162"        | "invalid UTF-8"                                 | # String with invalid UTF byte
      | Malformed Refined Unknown (Map Key) | "string"       | "d50c81a16ba3616263" | "invalid refinement key type"                 | # Ext Type 12, { "key_string": "abc" }
      | Malformed Refined Unknown (Payload) | "string"       | "d40ca46e6f6e65"    | "payload for ext type 12 not a map"           | # Ext Type 12, payload is string "none"

  Scenario Outline: Deserialize Malformed JSON <Description>
    Given the schema expects a "<TerraformType>"
    And an invalid JSON string "<MalformedJSON>" representing "<Description>"
    When the JSON string is deserialized according to the schema
    Then a deserialization error should occur indicating "<ExpectedErrorHint>"

    Examples:
      | Description                     | TerraformType      | MalformedJSON                   | ExpectedErrorHint                               |
      | Truncated String                | "string"           | "\"abc"                         | "unexpected end of JSON input"                  |
      | Truncated Object                | ["object", {"k":"string"}] | "{\"k\":\"v\""                  | "unexpected end of JSON input"                  |
      | Unescaped Quote in String       | "string"           | "\"hello\"world\""              | "invalid character 'w' after object key"        | # Or similar depending on parser strictness
      | Array Missing Comma             | ["list", "string"] | "[\"a\" \"b\"]"                 | "invalid character '\"' after array element"    |
      | String Instead of Number        | "number"           | "\"123\""                       | "type mismatch"                                 | # JSON string "123" for a number type
      | Number Instead of String        | "string"           | "123"                           | "type mismatch"                                 | # JSON number 123 for a string type
      | Object Instead of Array         | ["list", "string"] | "{}"                            | "type mismatch"                                 |
      | Invalid Dynamic Type Field      | "dynamic"          | "{\"type\":\"number\",\"val\":1}" | "missing 'value' field" or "unknown field 'val'" |
      | Invalid Dynamic Type Constraint | "dynamic"          | "{\"type\":\"[foo]\",\"value\":1}"| "invalid type constraint"                       |
</tbody></table>
