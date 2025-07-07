# Covers: docs/plugin-protocol/object-wire-format.md#Schema.NestedBlock-mapping-rules-for-messagepack
# Covers: docs/plugin-protocol/object-wire-format.md#Schema.NestedBlock-mapping-rules-for-json
Feature: Wire Format for Nested Blocks

  Background:
    Given a Terraform schema containing a nested block definition
    And the nested block "my_block" has an attribute "attr" of type "string"

  Scenario Outline: Serialize and Deserialize Nested Block with <NestingMode> via MessagePack
    Given the schema defines "my_block" with nesting mode "<NestingMode>"
    And a known Terraform value <KnownValue> for this nested block structure
    When the value is serialized to MessagePack according to the schema
    Then the MessagePack output for the "my_block" property should be <ExpectedMsgPackHex>
    When the MessagePack output is deserialized according to the schema
    Then the resulting Terraform value for "my_block" should be equivalent to <KnownValue>

    Examples:
      | NestingMode | KnownValue                                  | ExpectedMsgPackHex                                 | Comment                                              |
      | SINGLE      | {"attr": "val1"}                            | "81a461747472a476616c31"                           | # {"attr":"val1"}                                    |
      | SINGLE      | null                                        | "c0"                                               | # No block present                                   |
      | LIST        | [{"attr": "val1"}, {"attr": "val2"}]        | "9281a461747472a476616c3181a461747472a476616c32"     | # [{"attr":"val1"},{"attr":"val2"}]                  |
      | LIST        | []                                          | "90"                                               | # Empty list of blocks                             |
      | SET         | [{"attr": "val1"}]                          | "9181a461747472a476616c31"                           | # [{"attr":"val1"}] (order irrelevant for sets)    |
      | MAP         | {"label1": {"attr": "val1"}}                | "81a66c6162656c3181a461747472a476616c31"           | # {"label1": {"attr":"val1"}}                        |
      | GROUP       | {"attr": "val1"}                            | "81a461747472a476616c31"                           | # {"attr":"val1"}                                    |
      | GROUP       | {"attr": null}                              | "81a461747472c0"                                   | # Synthesized: {"attr":null} if block not present   |

  Scenario Outline: Serialize and Deserialize Nested Block with <NestingMode> via JSON
    Given the schema defines "my_block" with nesting mode "<NestingMode>"
    And a known Terraform value <KnownValue> for this nested block structure
    When the value is serialized to JSON according to the schema
    Then the JSON output for the "my_block" property should be "<ExpectedJSON>"
    When the JSON output is deserialized according to the schema
    Then the resulting Terraform value for "my_block" should be equivalent to <KnownValue>

    Examples:
      | NestingMode | KnownValue                                  | ExpectedJSON                                       | Comment                                              |
      | SINGLE      | {"attr": "val1"}                            | "{\"attr\":\"val1\"}"                              |
      | SINGLE      | null                                        | "null"                                             | # No block present                                   |
      | LIST        | [{"attr": "val1"}, {"attr": "val2"}]        | "[{\"attr\":\"val1\"},{\"attr\":\"val2\"}]"          |
      | LIST        | []                                          | "[]"                                               | # Empty list of blocks                             |
      | SET         | [{"attr": "val1"}]                          | "[{\"attr\":\"val1\"}]"                              | # Order irrelevant for sets                          |
      | MAP         | {"label1": {"attr": "val1"}}                | "{\"label1\":{\"attr\":\"val1\"}}"                  |
      | GROUP       | {"attr": "val1"}                            | "{\"attr\":\"val1\"}"                              |
      | GROUP       | {"attr": null}                              | "{\"attr\":null}"                                  | # Synthesized: {"attr":null} if block not present   |

  # Note: min_items/max_items validation deferral due to unknowns is a planning behavior,
  # harder to test purely at the serialization layer without a full plan context.
  # The BDD tests here focus on the correct serialization format given a known value.
  # Testing the LIST/SET length constraints in the presence of unknowns would require
  # simulating a planning phase.
