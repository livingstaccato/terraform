# Metadata:
# Covers: internal/configs/escaping_blocks_test.go
# TestFunctions:
# - TestEscapingBlockResource
# - TestEscapingBlockData
# - TestEscapingBlockModule
# - TestEscapingBlockProvider

Feature: Escaping Block Behavior in Configuration
  This feature describes the behavior of 'escaping blocks' (blocks named '_')
  which allow users to define arguments or nested blocks with names that might
  conflict with Terraform's meta-arguments, ensuring they are treated as
  user-defined rather than meta-arguments.

  Scenario Outline: Escaping Meta-Argument Names in <BlockType> Configurations
    Given a <BlockType> configuration for "<BlockName>" defined in "<TestDataPath>" which uses an escaping '_' block:
      """
      <BlockType> "<Type>" "<Name>" {
        # Meta-argument defined normally
        count = 2

        # User-defined arguments, some conflicting with meta-arguments, placed in escaping block
        _ {
          normal   = "yes"
          count    = "not actually count" # User-defined 'count'
          for_each = "not actually for_each" # User-defined 'for_each'
          lifecycle {} # User-defined block named 'lifecycle'
        }

        # Normal meta-argument block
        lifecycle {
          create_before_destroy = true
        }
        normal_block {}
      }
      """
    When the module containing this configuration is parsed
    Then the <BlockType> "<BlockName>" should be successfully parsed
    And its meta-argument 'count' should have the value 2
    And its meta-argument 'for_each' should be unset (or its default)
    And its 'lifecycle' meta-argument block should reflect 'create_before_destroy = true'
    And when its configuration body is evaluated against a schema expecting attributes "normal", "count", "for_each" and block "lifecycle", "normal_block":
      | ItemType  | Name       | ExpectedValueOrPresence |
      | Attribute | normal     | "yes"                   |
      | Attribute | count      | "not actually count"    |
      | Attribute | for_each   | "not actually for_each" |
      | Block     | lifecycle  | present                 | # User-defined block
      | Block     | normal_block | present               |

    Examples:
      | BlockType | BlockName      | TestDataPath                      | Type  | Name  |
      | Resource  | "foo.bar"      | testdata/escaping-blocks/resource | "foo" | "bar" |
      | Data      | "data.foo.bar" | testdata/escaping-blocks/data     | "foo" | "bar" |
      | Module    | "foo"          | testdata/escaping-blocks/module   |       | "foo" | # Type is not applicable for module block name

  Scenario: Escaping Meta-Argument Names in Provider Configurations
    Given a provider configuration for "foo.bar" defined in "testdata/escaping-blocks/provider" which uses an escaping '_' block:
      """
      provider "foo" {
        alias = "bar" # Meta-argument
        _ {
          normal  = "yes"
          alias   = "not actually alias"   # User-defined 'alias'
          version = "not actually version" # User-defined 'version'
        }
      }
      """
    When the module containing this configuration is parsed
    Then the provider configuration "foo.bar" should be successfully parsed
    And its meta-argument 'alias' (true alias) should be "bar"
    And its meta-argument 'version' (true version constraint) should be unset (or its default)
    And when its configuration body is evaluated against a schema expecting attributes "normal", "alias", "version":
      | ItemType  | Name    | ExpectedValueOrPresence |
      | Attribute | normal  | "yes"                   |
      | Attribute | alias   | "not actually alias"    |
      | Attribute | version | "not actually version"  |

  Scenario: Escaping Meta-Argument Names in Provisioner Blocks (within a Resource)
    Given a resource "foo.bar" configuration that includes a provisioner "shell" with an escaping '_' block:
      """
      resource "foo" "bar" {
        provisioner "shell" {
          # Meta-argument defined normally
          when = destroy

          _ {
            normal = "yep"
            when   = "hell freezes over" # User-defined 'when'
          }
        }
      }
      """
    When the module containing this configuration is parsed
    Then the resource "foo.bar" should have one provisioner
    And the provisioner's meta-argument 'when' should be 'destroy'
    And when the provisioner's configuration body is evaluated against a schema expecting attributes "normal", "when":
      | ItemType  | Name   | ExpectedValueOrPresence |
      | Attribute | normal | "yep"                   |
      | Attribute | when   | "hell freezes over"     |

```

Notes:
*   The Gherkin uses inline HCL snippets for clarity, representing the content of files in the `testdata` directories. The `<TestDataPath>` is just for reference to the Go test.
*   The scenarios clearly distinguish between the normally interpreted meta-arguments and the user-defined arguments/blocks placed inside the `_` escaping block.
*   The "evaluation against a schema" step is crucial to show that the escaped names are treated as regular schema-defined elements.

This covers `escaping_blocks_test.go`.

Next is `internal/configs/experiments_test.go`.
