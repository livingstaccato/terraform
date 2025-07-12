# Metadata:
# Covers: internal/addrs/output_value_test.go
# TestFunctions:
# - TestAbsOutputValueInstanceEqual_true
# - TestAbsOutputValueInstanceEqual_false
# - TestParseAbsOutputValueStr

Feature: Absolute Output Value Addressing
  This feature describes how absolute output values are addressed,
  compared for equality, and parsed from strings. These addresses are
  used to reference the outputs of modules.

  Scenario Outline: Absolute Output Value Self-Equality
    Given a module instance with address "<ModuleInstanceAddr>"
    And an output value named "<OutputName>" within this module instance, forming "OV1"
    When I compare "OV1" with itself
    Then they should be equal

    Examples:
      | ModuleInstanceAddr        | OutputName |
      | module.foo                | a          |
      | module.foo[1].module.bar  | b          |

  Scenario Outline: Absolute Output Value Comparison
    Given an absolute output value "OV1" in module instance "<Module1Addr>" with name "<Name1>"
    And an absolute output value "OV2" in module instance "<Module2Addr>" with name "<Name2>"
    When I compare "OV1" with "OV2"
    Then they should <EqualityResult>

    Examples:
      | Module1Addr | Name1 | Module2Addr             | Name2 | EqualityResult | Description                  |
      | module.foo  | a     | module.foo              | b     | NOT be equal   | Different names, same module |
      | module.foo  | a     | module.foo[1].module.bar| a     | NOT be equal   | Same name, different modules |

  Scenario Outline: Parsing Valid Absolute Output Value Strings
    Given an address string "<AddrString>" for an absolute output value
    When the address string is parsed
    Then the operation should be successful
    And the resulting absolute output value should be for output "<ExpectedOutputName>" in module instance "<ExpectedModuleInstanceAddr>"

    Examples:
      | AddrString             | ExpectedOutputName | ExpectedModuleInstanceAddr |
      | output.boop            | boop               | (RootModule)               |
      | module.foo.output.beep | beep               | module.foo                 |

  Scenario Outline: Parsing Invalid Absolute Output Value Strings
    Given an address string "<AddrString>" for an absolute output value
    When the address string is parsed
    Then the operation should fail with an error containing "<ExpectedErrorMessage>"

    Examples:
      | AddrString           | ExpectedErrorMessage                             |
      | module.foo           | An output name is required                       |
      | module.foo.output    | An output name is required                       |
      | module.foo.boop.beep | Output address must start with "output."         |
      | module.foo.output[0] | An output name is required                       |
      | output               | An output name is required                       |
      | output[0]            | An output name is required                       |

```

Notes for this Gherkin:

*   In the "Parsing Valid" scenario, `(RootModule)` is used to denote `RootModuleInstance` for clarity in the table.
*   The Gherkin clearly separates self-equality, comparison between different instances, successful parsing, and error handling for invalid parsing attempts.
*   The error messages in the "Parsing Invalid" scenario are taken directly from the test cases.

The next file to process is `internal/addrs/parse_ref_test.go`.
