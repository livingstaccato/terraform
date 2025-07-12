# Metadata:
# Covers: internal/configs/import_test.go
# TestFunctions:
# - TestParseConfigResourceFromExpression (internal helper, behavior tested via TestImportBlock_decode)
# - TestImportBlock_decode

Feature: Import Block Configuration Parsing and Validation
  This feature describes how Terraform parses and validates 'import' blocks
  within configuration files, ensuring correct arguments and target resource addressing.

  Scenario Outline: Successfully Parsing Valid Import Blocks
    Given a configuration file with an import block:
      """
      import {
        id = "<IDValue>"
        to = <ToAddressExpression>
      }
      """
    When the import block is decoded
    Then the operation should be successful
    And the resulting import definition should target the ConfigResource "<ExpectedConfigResource>"
    And its ID expression should evaluate to "<IDValue>"

    Examples:
      | IDValue   | ToAddressExpression             | ExpectedConfigResource                 | Description                       |
      | "i-12345" | aws_instance.web                | resource.aws_instance.web              | Simple resource                   |
      | "vol-abc" | aws_ebs_volume.data["key1"]     | resource.aws_ebs_volume.data           | Indexed resource                  |
      | "sg-def"  | module.vpc.aws_security_group.default | module.vpc.resource.aws_security_group.default | Resource in module                |

  Scenario Outline: Parsing Import Blocks with Invalid or Missing Arguments
    Given a configuration file with an import block:
      """
      <ImportBlockContent>
      """
    When the import block is decoded
    Then diagnostics should be produced
    And a diagnostic summary should contain "<ExpectedErrorMessagePart>"

    Examples:
      | ImportBlockContent                                 | ExpectedErrorMessagePart        | Description                                  |
      | import { to = aws_instance.web }                   | "Invalid import block"          | Missing 'id' or 'identity'                   |
      | import { id = "id1", identity = {id="id1"}, to = aws_instance.web } | "Invalid import block"          | Both 'id' and 'identity' provided            |
      | import { id = "id1" }                              | "Missing required argument"     | Missing 'to'                                 |
      | import { id = "id1", to = data.aws_ami.ubuntu }    | "Invalid import address"        | 'to' address refers to a data source         |
      | import { id = "id1", to = local.value }            | "Invalid import address"        | 'to' address refers to a local value         |
      | import { id = "id1", to = var.name }               | "Invalid import address"        | 'to' address refers to a variable            |

  Scenario Outline: Parsing 'to' Address Expression in Import Blocks (Internal Helper Behavior)
    # This tests the underlying parseConfigResourceFromExpression behavior
    Given an HCL expression "<ExpressionString>" representing a resource target
    When this expression is parsed to a ConfigResource address for an import block
    Then the resulting ConfigResource address should be "<ExpectedConfigResource>"
    And no diagnostics should be produced

    Examples:
      | ExpressionString                                | ExpectedConfigResource              |
      | test_instance.bar                               | resource.test_instance.bar          |
      | test_instance.bar[each.key]                     | resource.test_instance.bar          | # Index is ignored for ConfigResource
      | module.foo[each.key].test_instance.bar[each.key]| module.foo.resource.test_instance.bar | # Module index also ignored

```

Notes:
*   The first scenario outline covers successful parsing, ensuring the `to` address correctly resolves to a `ConfigResource` (stripping instance keys) and the `id` is captured.
*   The second scenario outline covers common validation errors for the `import` block structure.
*   The third scenario outline specifically addresses the behavior of `parseConfigResourceFromExpression` which is used internally by `decodeImportBlock` to process the `to` attribute. It highlights that instance indexing in the `to` expression is ignored when identifying the `ConfigResource`.

This covers `import_test.go`.

Next is `internal/configs/mock_provider_test.go`.
