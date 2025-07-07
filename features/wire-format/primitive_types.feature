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
      | Number (Zero)        | "number"      | 0               | "00"               | # Positive Fixint
      | Number (Pos Fixint)  | "number"      | 127             | "7f"               |
      | Number (Neg Fixint)  | "number"      | -1              | "ff"               |
      | Number (Neg Fixint 2)| "number"      | -32             | "e0"               |
      | Number (Uint8)       | "number"      | 200             | "ccC8"             | # 200
      | Number (Uint16)      | "number"      | 30000           | "cd7530"           | # 30000
      | Number (Uint32)      | "number"      | 1000000         | "ce000f4240"       | # 1,000,000
      | Number (Uint64)      | "number"      | "18446744073709551615" | "cfFFFFFFFFFFFFFFFF" | # 2^64 - 1 (as string to cty, then msgpack uint 64)
      | Number (Int8)        | "number"      | -100            | "d09c"             | # -100
      | Number (Int16)       | "number"      | -30000          | "d18ad0"           | # -30000
      | Number (Int32)       | "number"      | -1000000        | "d2fff0bdc0"       | # -1,000,000
      | Number (Int64)       | "number"      | "-9223372036854775808" | "d38000000000000000" | # -2^63 (as string to cty, then msgpack int 64)
      | Number (Float32)     | "number"      | 1.5             | "ca3fc00000"       | # May be encoded as Float64 by cty, but good to have a test value
      | Number (Float64)     | "number"      | 123.456         | "cb405edd2f1a9fbe77" |
      | Number (As String)   | "number"      | "12345678901234567890.12345678901234567890" | "d92c31323334353637383930313233343536373839302e3132333435363738393031323334353637383930" | # String representation for very high precision
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
      | Number (Large Integer) | "number"    | 9007199254740992  | "9007199254740992" | # Max safe integer for float64 (2^53)
      | Number (Beyond Float64 Precision) | "number" | "9007199254740992.1" | "9007199254740992.1" | # Spec implies JSON number, precision handled by arbitrary-precision nature
      | Number (Large Mantissa) | "number"   | "12345678901234567890.123456789" | "12345678901234567890.123456789" |
      | Boolean (True)       | "bool"        | true            | "true"           |
      | Boolean (False)      | "bool"        | false           | "false"          |
