# Covers: docs/plugin-protocol/object-wire-format.md#Schema.Attribute-mapping-rules-for-messagepack
# Covers: docs/plugin-protocol/object-wire-format.md#Schema.Attribute-mapping-rules-for-json
Feature: Wire Format for Primitive Types

  Scenario Outline: Serialize and Deserialize <PrimitiveType> via MessagePack
    Given a Terraform schema for an attribute of type "<TerraformType>"
    And a known Terraform value <KnownValue> of type "<TerraformType>"
    When the value is serialized to MessagePack according to the schema
    Then the MessagePack output should be <ExpectedMsgPackHex>
    When the MessagePack output is deserialized according to the schema
    Then the resulting Terraform value should be equivalent to <KnownValue>

    Examples:
      | PrimitiveType        | TerraformType | KnownValue      | ExpectedMsgPackHex |
      | String               | "string"      | "hello"         | "a568656c6c6f"     | # "hello"
      | String (UTF-8)       | "string"      | "こんにちは"      | "e38193e38293e381abe381a1e381af" | # "こんにちは"
      | Number (Integer)     | "number"      | 123             | "7b"               | # 123 (positive fixint)
      | Number (Integer Neg) | "number"      | -10             | "f6"               | # -10 (negative fixint)
      | Number (Large Int)   | "number"      | 300             | "cd012c"           | # 300 (uint 16)
      | Number (Float)       | "number"      | 123.456         | "cb405edd2f1a9fbe77" | # 123.456 (float 64)
      | Number (As String)   | "number"      | "12345678901234567890.123456789" | "d92231323334353637383930313233343536373839302e313233343536373839" | # "12345678901234567890.123456789" (str 8 + length)
      | Boolean (True)       | "bool"        | true            | "c3"               |
      | Boolean (False)      | "bool"        | false           | "c2"               |

  Scenario Outline: Serialize and Deserialize <PrimitiveType> via JSON
    Given a Terraform schema for an attribute of type "<TerraformType>"
    And a known Terraform value <KnownValue> of type "<TerraformType>"
    When the value is serialized to JSON according to the schema
    Then the JSON output should be "<ExpectedJSON>"
    When the JSON output is deserialized according to the schema
    Then the resulting Terraform value should be equivalent to <KnownValue>

    Examples:
      | PrimitiveType        | TerraformType | KnownValue      | ExpectedJSON     |
      | String               | "string"      | "hello"         | "\"hello\""      |
      | String (UTF-8)       | "string"      | "こんにちは"      | "\"こんにちは\""   |
      | Number (Integer)     | "number"      | 123             | "123"            |
      | Number (Float)       | "number"      | 123.456         | "123.456"        |
      | Number (Large Mantissa) | "number"   | "12345678901234567890.123456789" | "12345678901234567890.123456789" | # Numbers that might exceed standard float64 precision are handled as strings in JSON by some cty operations, but here we expect the number type if possible. The spec notes it's a JSON number.
      | Boolean (True)       | "bool"        | true            | "true"           |
      | Boolean (False)      | "bool"        | false           | "false"          |
