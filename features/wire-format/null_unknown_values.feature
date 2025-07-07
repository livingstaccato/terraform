# Covers: docs/plugin-protocol/object-wire-format.md#Schema.Attribute-mapping-rules-for-messagepack (Nulls and Unknowns)
# Covers: docs/plugin-protocol/object-wire-format.md#Schema.Attribute-mapping-rules-for-json (Nulls)
# Inspired by: internal/plugin/grpc_provider_test.go (TestGRPCProvider_ReadEmptyJSON for nulls)
Feature: Wire Format for Null and Unknown Values

  Scenario Outline: Serialize and Deserialize Null <ValueDescription> via MessagePack
    Given a Terraform schema for an attribute of type "<TerraformType>"
    And a null Terraform value of type "<TerraformType>"
    When the value is serialized to MessagePack according to the schema
    Then the MessagePack output should be "c0" # MessagePack nil
    When the MessagePack output is deserialized according to the schema
    Then the resulting Terraform value should be a null value of type "<TerraformType>"

    Examples:
      | ValueDescription | TerraformType     |
      | String           | "string"          |
      | Number           | "number"          |
      | Boolean          | "bool"            |
      | List             | ["list", "string"] |
      | Map              | ["map", "string"] |
      | Object           | ["object", {"name": "string"}] |

  Scenario Outline: Serialize and Deserialize Null <ValueDescription> via JSON
    Given a Terraform schema for an attribute of type "<TerraformType>"
    And a null Terraform value of type "<TerraformType>"
    When the value is serialized to JSON according to the schema
    Then the JSON output should be "null"
    When the JSON output is deserialized according to the schema
    Then the resulting Terraform value should be a null value of type "<TerraformType>"

    Examples:
      | ValueDescription | TerraformType     |
      | String           | "string"          |
      | Number           | "number"          |
      | Boolean          | "bool"            |
      | List             | ["list", "string"] |
      | Map              | ["map", "string"] |
      | Object           | ["object", {"name": "string"}] |

  Scenario Outline: Serialize and Deserialize Unrefined Unknown value (ext code 0) for <TerraformTypeDescription> via MessagePack
    Given a Terraform schema for an attribute of type "<TerraformType>"
    And an unrefined unknown Terraform value of type "<TerraformType>"
    When the value is serialized to MessagePack according to the schema
    Then the MessagePack output should be "d40000" # fixext1, type 0, 0 bytes data (payload ignored)
    When the MessagePack output is deserialized according to the schema
    Then the resulting Terraform value should be an unrefined unknown value of type "<TerraformType>"

    Examples:
      | TerraformTypeDescription | TerraformType     |
      | String                   | "string"          |
      | Number                   | "number"          |
      | List of bools            | ["list", "bool"]  |

  Scenario: Serialize and Deserialize Refined Unknown (ext code 12) - Nullness (Definitely Null) via MessagePack
    Given a Terraform schema for an attribute of type "string"
    And a refined unknown Terraform string value that is definitely null
    When the value is serialized to MessagePack according to the schema
    Then the MessagePack output should be "d50c8101c3" # fixext2, type 12, payload: {1: true}
      # d5 = fixext 2 (len 2 for payload)
      # 0c = type 12 (refined unknown)
      # 81 = map 1 element
      # 01 = key 1 (nullness)
      # c3 = value true
    When the MessagePack output is deserialized according to the schema
    Then the resulting Terraform value should be a refined unknown string value that is definitely null

  Scenario: Serialize and Deserialize Refined Unknown (ext code 12) - Nullness (Definitely Not Null) via MessagePack
    Given a Terraform schema for an attribute of type "string"
    And a refined unknown Terraform string value that is definitely not null
    When the value is serialized to MessagePack according to the schema
    Then the MessagePack output should be "d50c8101c2" # fixext2, type 12, payload: {1: false}
      # d5 = fixext 2
      # 0c = type 12
      # 81 = map 1 element
      # 01 = key 1 (nullness)
      # c2 = value false
    When the MessagePack output is deserialized according to the schema
    Then the resulting Terraform value should be a refined unknown string value that is definitely not null

  Scenario: Serialize and Deserialize Refined Unknown (ext code 12) - String Prefix via MessagePack
    Given a Terraform schema for an attribute of type "string"
    And a refined unknown Terraform string value with known prefix "abc"
    When the value is serialized to MessagePack according to the schema
    Then the MessagePack output should be "d70c8102a3616263" # fixext4, type 12, payload: {2: "abc"}
      # d7 = fixext 4
      # 0c = type 12
      # 81 = map 1 element
      # 02 = key 2 (string prefix)
      # a3 = str (fixstr) len 3
      # 616263 = "abc"
    When the MessagePack output is deserialized according to the schema
    Then the resulting Terraform value should be a refined unknown string value with known prefix "abc"

  Scenario: Serialize and Deserialize Refined Unknown (ext code 12) - Number Bounds via MessagePack
    Given a Terraform schema for an attribute of type "number"
    And a refined unknown Terraform number value with lower bound 10 (inclusive) and upper bound 20 (exclusive)
    When the value is serialized to MessagePack according to the schema
    Then the MessagePack output should be "da000e0c8203920ac3049214c2" # ext16, type 12, payload: {3:[10,true], 4:[20,false]}
      # da000e = ext 16, len 14
      # 0c     = type 12
      # 82     = map 2 elements
      # 03     = key 3 (lower bound)
      # 92     = array 2 elements
      # 0a     = value 10 (positive fixint)
      # c3     = value true (inclusive)
      # 04     = key 4 (upper bound)
      # 92     = array 2 elements
      # 14     = value 20 (positive fixint)
      # c2     = value false (exclusive)
    When the MessagePack output is deserialized according to the schema
    Then the resulting Terraform value should be a refined unknown number value with lower bound 10 (inclusive) and upper bound 20 (exclusive)

  Scenario: Serialize and Deserialize Refined Unknown (ext code 12) - Collection Length Bounds via MessagePack
    Given a Terraform schema for an attribute of type ["list", "string"]
    And a refined unknown Terraform list value with min length 1 and max length 5
    When the value is serialized to MessagePack according to the schema
    Then the MessagePack output should be "d60c8205010605" # fixext8, type 12, payload: {5:1, 6:5}
      # d6 = fixext 8
      # 0c = type 12
      # 82 = map 2 elements
      # 05 = key 5 (min length)
      # 01 = value 1
      # 06 = key 6 (max length)
      # 05 = value 5
    When the MessagePack output is deserialized according to the schema
    Then the resulting Terraform value should be a refined unknown list value with min length 1 and max length 5

  Scenario: Server should treat any MessagePack extension code as unknown (non-12)
    Given a Terraform schema for an attribute of type "string"
    And an incoming MessagePack payload "d4ff00" # fixext1, type 255 (arbitrary non-12 type), 0 bytes data
    When the MessagePack output is deserialized according to the schema
    Then the resulting Terraform value should be an unrefined unknown value of type "string"
    And the extension payload should be ignored
