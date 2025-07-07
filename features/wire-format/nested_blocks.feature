# Covers: docs/plugin-protocol/object-wire-format.md#Schema.NestedBlock-mapping-rules-for-messagepack
# Covers: docs/plugin-protocol/object-wire-format.md#Schema.NestedBlock-mapping-rules-for-json
Feature: Wire Format for Nested Blocks

  Background:
    Given a Terraform schema containing a nested block definition "my_block"
    And "my_block" has an attribute "attr1" of type "string"
    And "my_block" can optionally have a nested block "inner_block"
    And "inner_block" has an attribute "attr2" of type "number"

  Scenario Outline: Serialize and Deserialize Nested Block "my_block" with <NestingMode> via MessagePack
    Given the schema defines "my_block" with nesting mode "<NestingMode>"
    And a known Terraform value <KnownValue> for this "my_block" structure
    When the value is serialized to MessagePack according to the schema
    Then the MessagePack output for the "my_block" property should be <ExpectedMsgPackHex>
    When the MessagePack output is deserialized according to the schema
    Then the resulting Terraform value for "my_block" should be equivalent to <KnownValue>

    Examples:
      | NestingMode | KnownValue                                            | ExpectedMsgPackHex                                                 | Comment                                                     |
      | SINGLE      | {"attr1": "val1"}                                     | "81a56174747231a476616c31"                                         | # {"attr1":"val1"}                                          |
      | SINGLE      | null                                                  | "c0"                                                               | # No block present                                          |
      | LIST        | [{"attr1": "v1"}, {"attr1": "v2"}]                    | "9281a56174747231a2763181a56174747231a27632"                       | # [{"attr1":"v1"},{"attr1":"v2"}]                           |
      | LIST        | []                                                    | "90"                                                               | # Empty list of blocks                                      |
      | LIST        | [{"attr1":"v1", "inner_block": [{"attr2":10}]}]       | "9182a56174747231a27631ab696e6e65725f626c6f636b9181a561747472320a" | # [{"attr1":"v1", "inner_block": [{"attr2":10}]}]           |
      | SET         | [{"attr1": "v1"}]                                     | "9181a56174747231a27631"                                           | # [{"attr1":"v1"}] (order irrelevant for sets)             |
      | MAP         | {"label1": {"attr1": "v1"}}                           | "81a66c6162656c3181a56174747231a27631"                             | # {"label1": {"attr1":"v1"}}                                |
      | GROUP       | {"attr1": "val1"}                                     | "81a56174747231a476616c31"                                         | # {"attr1":"val1"}                                          |
      | GROUP       | {"attr1": null, "inner_block": null}                  | "82a56174747231c0ab696e6e65725f626c6f636bc0"                       | # Synthesized: {"attr1":null, "inner_block":null}           |

  Scenario Outline: Serialize and Deserialize Nested Block "my_block" with <NestingMode> via JSON
    Given the schema defines "my_block" with nesting mode "<NestingMode>"
    And a known Terraform value <KnownValue> for this nested block structure
    When the value is serialized to JSON according to the schema
    Then the JSON output for the "my_block" property should be "<ExpectedJSON>"
    When the JSON output is deserialized according to the schema
    Then the resulting Terraform value for "my_block" should be equivalent to <KnownValue>

    Examples:
      | NestingMode | KnownValue                                            | ExpectedJSON                                                                 | Comment                                                     |
      | SINGLE      | {"attr1": "val1"}                                     | "{\"attr1\":\"val1\"}"                                                      |
      | SINGLE      | null                                                  | "null"                                                                     | # No block present                                          |
      | LIST        | [{"attr1": "v1"}, {"attr1": "v2"}]                    | "[{\"attr1\":\"v1\"},{\"attr1\":\"v2\"}]"                                   |
      | LIST        | []                                                    | "[]"                                                                       | # Empty list of blocks                                      |
      | LIST        | [{"attr1":"v1", "inner_block": [{"attr2":10}]}]       | "[{\"attr1\":\"v1\",\"inner_block\":[{\"attr2\":10}]}]"                     |
      | SET         | [{"attr1": "v1"}]                                     | "[{\"attr1\":\"v1\"}]"                                                      | # Order irrelevant for sets                                 |
      | MAP         | {"label1": {"attr1": "v1"}}                           | "{\"label1\":{\"attr1\":\"v1\"}}"                                           |
      | GROUP       | {"attr1": "val1"}                                     | "{\"attr1\":\"val1\"}"                                                      |
      | GROUP       | {"attr1": null, "inner_block": null}                  | "{\"attr1\":null,\"inner_block\":null}"                                     | # Synthesized: {"attr1":null, "inner_block":null}           |

  # Note: min_items/max_items validation deferral due to unknowns is a planning behavior,
  # harder to test purely at the serialization layer without a full plan context.
  # The BDD tests here focus on the correct serialization format given a known value.
  # Testing the LIST/SET length constraints in the presence of unknowns would require
  # simulating a planning phase.
