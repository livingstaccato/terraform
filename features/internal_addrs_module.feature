# Source Go File: internal/addrs/module.go
# Source Go Test: internal/addrs/module_test.go

Feature: Module Addressing
  This feature describes how Terraform module paths (addrs.Module) are
  represented, stringified, and compared for equality. A module path
  is a sequence of module names from the root to a specific module.

  Background:
    Given the Terraform addressing system for modules

  Scenario Outline: Module path string representation
    Given a Module defined by the path segments <Segments>
      # Segments is a list of strings, e.g., ["alpha", "beta"] or [] for root
    When its String() method is called
    Then the result should be "<ExpectedString>"

    Examples:
      | Segments            | ExpectedString                           |
      | []                  | ""                                       | # Root module
      | ["alpha"]           | "module.alpha"                           |
      | ["alpha", "beta"]   | "module.alpha.module.beta"               |
      | ["a", "b", "c"]     | "module.a.module.b.module.c"             |

  Scenario Outline: Module path equality
    Given Module A is defined by path segments <SegmentsA>
    And Module B is defined by path segments <SegmentsB>
    When Module A is compared with Module B using Equal()
    Then the result should be <IsEqual>

    Examples:
      | SegmentsA           | SegmentsB           | IsEqual |
      | []                  | []                  | true    | # Root vs Root
      | ["a"]               | ["a"]               | true    |
      | ["a", "b"]          | ["a", "b"]          | true    |
      | []                  | ["a"]               | false   | # Root vs non-root
      | ["a"]               | []                  | false   |
      | ["a"]               | ["b"]               | false   | # Different name at same level
      | ["a"]               | ["a", "a"]          | false   | # Different length
      | ["a", "b"]          | ["a", "B"]          | false   | # Case sensitive difference
      | ["a", "b", "c"]     | ["a", "b", "c"]     | true    |

  # Note:
  # - The `cty` aspects are indirect. Module paths are fundamental to how Terraform
  #   organizes configuration, state, and plans, which involve cty.Value.
  # - This feature primarily tests the construction, stringification, and equality of module path addresses.
  # - Step definitions will need to parse segment lists into addrs.Module instances.
  # - RootModule is a predefined constant equivalent to Module{}.
