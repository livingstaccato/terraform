# Covers: docs/plugin-protocol/object-wire-format.md#Schema.Attribute-mapping-rules-for-messagepack
# Covers: docs/plugin-protocol/object-wire-format.md#Schema.Attribute-mapping-rules-for-json
Feature: Wire Format for Collection Types (List, Set, Map, Object, Tuple)

  Background:
    Given a Terraform schema defined for a collection

  Scenario Outline: Serialize and Deserialize <CollectionTypeDescription> via MessagePack
    Given the schema specifies a "<TerraformType>"
    And a known Terraform value <KnownValue> for this collection
    When the value is serialized to MessagePack according to the schema
    Then the MessagePack output should be <ExpectedMsgPackHex>
    When the MessagePack output is deserialized according to the schema
    Then the resulting Terraform value should be equivalent to <KnownValue>

    Examples:
      | CollectionTypeDescription | TerraformType               | KnownValue                                                                 | ExpectedMsgPackHex                                           |
      | Empty List                | ["list", "string"]          | []                                                                         | "90"                                                         | # Empty array
      | List of Strings           | ["list", "string"]          | ["a", "b"]                                                                 | "92a161a162"                                                 | # Array of 2: "a", "b"
      | List of Mixed Primitives  | ["list", "dynamic"]         | [1, "two", true]                                                           | "9392ca00c392ca0622737472696e6722a374776f92ca0422626f6f6c22c3" | # Array of 3 dynamic values: [1, "two", true]. This is complex due to dynamic wrapper. Simplified: array of [1(msgpack), "two"(msgpack), true(msgpack)] if type was concrete e.g. `["tuple", ["number", "string", "bool"]]` would be `9301a374776fc3`
      | Empty Set                 | ["set", "string"]           | []                                                                         | "90"                                                         | # Empty array (order undefined for set, but empty is deterministic)
      | Set of Numbers            | ["set", "number"]           | [1, 2]                                                                     | "920102"                                                     | # Array of 2: 1, 2 (order for serialization can vary, this is one valid form)
      | Empty Map                 | ["map", "string"]           | {}                                                                         | "80"                                                         | # Empty map
      | Map String to Number      | ["map", "number"]           | {"a": 1, "b": 2}                                                           | "82a16101a16202"                                             | # Map of 2: "a":1, "b":2 (order of pairs can vary)
      | Empty Object              | ["object", {}]              | {}                                                                         | "80"                                                         |
      | Simple Object             | ["object", {"name":"string", "age":"number"}] | {"name":"TF", "age":10}                                    | "82a46e616d65a25446a36167650a"                               | # Map of 2: "name":"TF", "age":10 (order of pairs can vary)
      | Empty Tuple               | ["tuple", []]               | []                                                                         | "90"                                                         |
      | Tuple of Primitives       | ["tuple", ["string", "number"]] | ["hi", 42]                                                               | "92a268692a"                                                 | # Array of 2: "hi", 42

  Scenario Outline: Serialize and Deserialize <CollectionTypeDescription> via JSON
    Given the schema specifies a "<TerraformType>"
    And a known Terraform value <KnownValue> for this collection
    When the value is serialized to JSON according to the schema
    Then the JSON output should be "<ExpectedJSON>"
    When the JSON output is deserialized according to the schema
    Then the resulting Terraform value should be equivalent to <KnownValue>

    Examples:
      | CollectionTypeDescription | TerraformType               | KnownValue                                                                 | ExpectedJSON                                                 |
      | Empty List                | ["list", "string"]          | []                                                                         | "[]"                                                         |
      | List of Strings           | ["list", "string"]          | ["a", "b"]                                                                 | "[\"a\",\"b\"]"                                               |
      | List of Mixed Primitives  | ["list", "dynamic"]         | [1, "two", true]                                                           | "[{\"type\":\"number\",\"value\":1},{\"type\":\"string\",\"value\":\"two\"},{\"type\":\"bool\",\"value\":true}]" |
      | Empty Set                 | ["set", "string"]           | []                                                                         | "[]"                                                         |
      | Set of Numbers            | ["set", "number"]           | [1, 2]                                                                     | "[1,2]"                                                      | # Order for serialization can vary for sets
      | Empty Map                 | ["map", "string"]           | {}                                                                         | "{}"                                                         |
      | Map String to Number      | ["map", "number"]           | {"a": 1, "b": 2}                                                           | "{\"a\":1,\"b\":2}"                                           | # Order of keys can vary in JSON objects
      | Empty Object              | ["object", {}]              | {}                                                                         | "{}"                                                         |
      | Simple Object             | ["object", {"name":"string", "age":"number"}] | {"name":"TF", "age":10}                                    | "{\"age\":10,\"name\":\"TF\"}"                               | # Order of keys can vary
      | Empty Tuple               | ["tuple", []]               | []                                                                         | "[]"                                                         |
      | Tuple of Primitives       | ["tuple", ["string", "number"]] | ["hi", 42]                                                               | "[\"hi\",42]"                                                |

  Scenario: Serialize and Deserialize "dynamic" type via MessagePack
    Given a Terraform schema for an attribute of type "dynamic"
    And a Terraform value "test" (string) to be serialized as dynamic
    When the value is serialized to MessagePack according to the schema
    Then the MessagePack output should be "92c40822737472696e6722a474657374"
      # 92 = array 2 elements
      # c408 = bin8 with 8 bytes for type constraint "string" (JSON encoded)
      # 22737472696e6722 = "\"string\""
      # a474657374 = "test" (fixstr)
    When the MessagePack output is deserialized according to the schema
    Then the resulting Terraform value should be "test" (string)

  Scenario: Serialize and Deserialize "dynamic" type via JSON
    Given a Terraform schema for an attribute of type "dynamic"
    And a Terraform value 123 (number) to be serialized as dynamic
    When the value is serialized to JSON according to the schema
    Then the JSON output should be "{\"type\":\"number\",\"value\":123}"
    When the JSON output is deserialized according to the schema
    Then the resulting Terraform value should be 123 (number)
