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
      | Empty List                | ["list", "string"]          | []                                                                         | "90"                                                         |
      | List of Strings           | ["list", "string"]          | ["a", "b"]                                                                 | "92a161a162"                                                 |
      | List of Objects           | ["list", ["object", {"id":"string"}]] | [{"id":"one"}, {"id":"two"}]                                       | "9281a26964a36f6e6581a26964a374776f"                         | # [{"id":"one"}, {"id":"two"}]
      | Empty Set                 | ["set", "string"]           | []                                                                         | "90"                                                         |
      | Set of Numbers            | ["set", "number"]           | [1, 2]                                                                     | "920102"                                                     | # Order can vary, this is one valid form
      | Empty Map                 | ["map", "string"]           | {}                                                                         | "80"                                                         |
      | Map String to Number      | ["map", "number"]           | {"a": 1, "b": 2}                                                           | "82a16101a16202"                                             | # Order of pairs can vary
      | Map String to List        | ["map", ["list", "string"]] | {"key1": ["v1", "v2"]}                                                     | "81a46b65793192a27631a27632"                                 | # {"key1": ["v1", "v2"]}
      | Empty Object              | ["object", {}]              | {}                                                                         | "80"                                                         |
      | Simple Object             | ["object", {"name":"string", "age":"number"}] | {"name":"TF", "age":10}                                    | "82a36167650aa46e616d65a25446"                               | # {"age":10,"name":"TF"} (keys sorted alphabetically for canonical example)
      | Object with Nested Object | ["object", {"name":"string", "details":["object", {"attr":"string"}]}] | {"name":"TF", "details":{"attr":"val"}} | "82a764657461696c7381a461747472a376616ca46e616d65a25446"     | # {"details":{"attr":"val"},"name":"TF"}
      | Empty Tuple               | ["tuple", []]               | []                                                                         | "90"                                                         |
      | Tuple of Primitives       | ["tuple", ["string", "number"]] | ["hi", 42]                                                               | "92a268692a"                                                 |
      | Tuple with Nested List    | ["tuple", [["list", "bool"]]] | [[true, false]]                                                            | "9192c3c2"                                                   | # [[true,false]]

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
      | List of Objects           | ["list", ["object", {"id":"string"}]] | [{"id":"one"}, {"id":"two"}]                                       | "[{\"id\":\"one\"},{\"id\":\"two\"}]"                         |
      | Empty Set                 | ["set", "string"]           | []                                                                         | "[]"                                                         |
      | Set of Numbers            | ["set", "number"]           | [1, 2]                                                                     | "[1,2]"                                                      | # Order for serialization can vary for sets
      | Empty Map                 | ["map", "string"]           | {}                                                                         | "{}"                                                         |
      | Map String to Number      | ["map", "number"]           | {"a": 1, "b": 2}                                                           | "{\"a\":1,\"b\":2}"                                           | # Order of keys can vary in JSON objects
      | Map String to List        | ["map", ["list", "string"]] | {"key1": ["v1", "v2"]}                                                     | "{\"key1\":[\"v1\",\"v2\"]}"                                  |
      | Empty Object              | ["object", {}]              | {}                                                                         | "{}"                                                         |
      | Simple Object             | ["object", {"name":"string", "age":"number"}] | {"name":"TF", "age":10}                                    | "{\"age\":10,\"name\":\"TF\"}"                               | # Order of keys can vary
      | Object with Nested Object | ["object", {"name":"string", "details":["object", {"attr":"string"}]}] | {"name":"TF", "details":{"attr":"val"}} | "{\"details\":{\"attr\":\"val\"},\"name\":\"TF\"}"             | # Order of keys can vary
      | Empty Tuple               | ["tuple", []]               | []                                                                         | "[]"                                                         |
      | Tuple of Primitives       | ["tuple", ["string", "number"]] | ["hi", 42]                                                               | "[\"hi\",42]"                                                |
      | Tuple with Nested List    | ["tuple", [["list", "bool"]]] | [[true, false]]                                                            | "[[true,false]]"                                             |

  Scenario Outline: Serialize and Deserialize "dynamic" type holding <ActualTypeDescription> via MessagePack
    Given a Terraform schema for an attribute of type "dynamic"
    And a Terraform value <KnownValue> of actual type "<ActualTerraformType>" to be serialized as dynamic
    When the value is serialized to MessagePack according to the schema
    Then the MessagePack output should be <ExpectedMsgPackHex>
    When the MessagePack output is deserialized according to the schema
    Then the resulting Terraform value should be equivalent to <KnownValue> and of type "<ActualTerraformType>"

    Examples:
      | ActualTypeDescription | KnownValue         | ActualTerraformType   | ExpectedMsgPackHex                                       | Comment                                                                         |
      | String                | "test"             | "string"              | "92c40822737472696e6722a474657374"                       | # Dynamic(String): [json_type_string("string"), msgpack_string("test")]         |
      | Number                | 123                | "number"              | "92c408226e756d626572227b"                               | # Dynamic(Number): [json_type_string("number"), msgpack_int(123)]               |
      | Boolean               | true               | "bool"                | "92c40622626f6f6c22c3"                                   | # Dynamic(Bool): [json_type_string("bool"), msgpack_bool(true)]                 |
      | List of Numbers       | [1,2]              | ["list", "number"]    | "92c4125b226c697374222c226e756d626572225d920102"         | # Dynamic(List<Number>): [json_type_string("[\"list\",\"number\"]"), msgpack_array([1,2])] |
      | Empty Map             | {}                 | ["map", "string"]     | "92c4115b226d6170222c22737472696e67225d80"               | # Dynamic(Map<String>): [json_type_string("[\"map\",\"string\"]"), msgpack_empty_map] |
      | Null String (Dynamic) | null               | "string"              | "92c40822737472696e6722c0"                               | # Dynamic(Null String): [json_type_string("string"), msgpack_nil]               |

  Scenario Outline: Serialize and Deserialize "dynamic" type holding <ActualTypeDescription> via JSON
    Given a Terraform schema for an attribute of type "dynamic"
    And a Terraform value <KnownValue> of actual type "<ActualTerraformType>" to be serialized as dynamic
    When the value is serialized to JSON according to the schema
    Then the JSON output should be "<ExpectedJSON>"
    When the JSON output is deserialized according to the schema
    Then the resulting Terraform value should be equivalent to <KnownValue> and of type "<ActualTerraformType>"

    Examples:
      | ActualTypeDescription | KnownValue         | ActualTerraformType   | ExpectedJSON                                                                 |
      | String                | "test"             | "string"              | "{\"type\":\"string\",\"value\":\"test\"}"                                   |
      | Number                | 123                | "number"              | "{\"type\":\"number\",\"value\":123}"                                       |
      | Boolean               | true               | "bool"                | "{\"type\":\"bool\",\"value\":true}"                                        |
      | List of Numbers       | [1,2]              | ["list", "number"]    | "{\"type\":[\"list\",\"number\"],\"value\":[1,2]}"                           |
      | Object                | {"key":"val"}      | ["object",{"key":"string"}] | "{\"type\":[\"object\",{\"key\":\"string\"}],\"value\":{\"key\":\"val\"}}"  |
      | Null String (Dynamic) | null               | "string"              | "{\"type\":\"string\",\"value\":null}"                                      |
