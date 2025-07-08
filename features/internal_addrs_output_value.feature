# Source Go File: internal/addrs/output_value.go
# Source Go Test: internal/addrs/output_value_test.go

Feature: Absolute Output Value Addressing and Parsing
  This feature describes how Terraform absolute output values (AbsOutputValue)
  are represented, stringified, compared for equality, and parsed from strings.

  Background:
    Given the Terraform addressing system for outputs

  Scenario Outline: AbsOutputValue equality
    Given an AbsOutputValue A with Module Path "<ModulePathA>" and Output Name "<OutputNameA>"
    And an AbsOutputValue B with Module Path "<ModulePathB>" and Output Name "<OutputNameB>"
    When AbsOutputValue A is compared with AbsOutputValue B using Equal()
    Then the result should be <IsEqual>

    Examples:
      | ModulePathA             | OutputNameA | ModulePathB             | OutputNameB | IsEqual |
      | "module.foo"            | "a"         | "module.foo"            | "a"         | true    |
      | "module.foo[1].module.bar" | "b"         | "module.foo[1].module.bar" | "b"         | true    |
      | "module.foo"            | "a"         | "module.foo"            | "b"         | false   | # Different Output Name
      | "module.foo"            | "a"         | "module.foo[1].module.bar" | "a"         | false   | # Different Module Path

  Scenario Outline: Parsing string to AbsOutputValue (Successful Cases)
    Given the address string "<AddressString>"
    When ParseAbsOutputValueStr is called with this string
    Then the parsing should succeed without diagnostics
    And the resulting AbsOutputValue should have Module Path "<ExpectedModulePath>" and Output Name "<ExpectedOutputName>"

    Examples:
      | AddressString          | ExpectedModulePath | ExpectedOutputName |
      | "output.boop"          | ""                 | "boop"             |
      | "module.foo.output.beep" | "module.foo"       | "beep"             |
      | "module.parent[0].module.child.output.value" | "module.parent[0].module.child" | "value" |

  Scenario Outline: Parsing string to AbsOutputValue (Failure Cases)
    Given the address string "<AddressString>"
    When ParseAbsOutputValueStr is called with this string
    Then parsing should fail with a diagnostic summary containing "<ExpectedErrorSummary>"

    Examples:
      | AddressString          | ExpectedErrorSummary         |
      | "module.foo"           | "An output name is required" |
      | "module.foo.output"    | "An output name is required" |
      | "module.foo.boop.beep" | "Output address must start with \"output.\"" |
      | "module.foo.output[0]" | "An output name is required" | # Indexing not allowed on "output" itself
      | "output"               | "An output name is required" |
      | "output[0]"            | "An output name is required" |

  # Note:
  # - ModulePath is a string representation of an addrs.ModuleInstance.
  # - Step definitions will need to parse ModulePath strings into addrs.ModuleInstance.
  # - The cty aspects are indirect, as these address types are fundamental to how Terraform
  #   organizes and references configuration, state, and plan, which often involve cty.Value.
  # - This feature focuses on the string representation, parsing, and equality of absolute output value addresses.
  # - String() method is implicitly tested by its usage in test output/comparisons.
