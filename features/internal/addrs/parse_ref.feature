# Metadata:
# Covers: internal/addrs/parse_ref_test.go
# TestFunctions:
# - TestParseRefInTestingScope
# - TestParseRef

Feature: Parsing HCL Traversals into References
  This feature describes how Terraform parses HCL traversal expressions (like `var.foo`, `my_resource.example.id`)
  into structured Reference objects, which identify specific addressable items in a configuration
  and any further attribute or index traversals.

  Scenario Outline: Parsing Valid References in Standard Scope
    Given an HCL traversal string "<TraversalString>" in a standard scope
    When it is parsed as a reference
    Then the parsing should be successful
    And the reference subject should be a "<SubjectType>" representing "<SubjectAddress>"
    And the remaining traversal should be "<RemainingTraversal>"

    Examples:
      # Variables
      | TraversalString | SubjectType   | SubjectAddress | RemainingTraversal |
      | var.foo         | InputVariable | var.foo        |                    |
      | var.foo.blah    | InputVariable | var.foo        | .blah              |
      # Locals
      | local.foo       | LocalValue    | local.foo      |                    |
      | local.foo.blah  | LocalValue    | local.foo      | .blah              |
      # Count
      | count.index     | CountAttr     | count.index    |                    |
      # Each
      | each.key        | ForEachAttr   | each.key       |                    |
      | each.value      | ForEachAttr   | each.value     |                    |
      # Path
      | path.module     | PathAttr      | path.module    |                    |
      # Self
      | self            | Self          | self           |                    |
      | self.blah       | Self          | self           | .blah              |
      # Terraform
      | terraform.workspace | TerraformAttr | terraform.workspace |              |
      # Managed Resources (Implicit)
      | aws_instance.web    | Resource          | aws_instance.web             |                    |
      | aws_instance.web.id | ResourceInstance  | aws_instance.web (implicit)  | .id                |
      | aws_instance.web["key"].id | ResourceInstance | aws_instance.web["key"] | .id              |
      # Managed Resources (Explicit)
      | resource.aws_instance.web | Resource   | aws_instance.web             |                    |
      # Data Sources
      | data.aws_ami.ubuntu    | Resource          | data.aws_ami.ubuntu          |                    |
      | data.aws_ami.ubuntu.id | ResourceInstance  | data.aws_ami.ubuntu (implicit) | .id              |
      # Module Calls and Outputs
      | module.child           | ModuleCall             | module.child                 |                    |
      | module.child.output_val| ModuleCallInstanceOutput | module.child.output_val      |                    | # Output from non-indexed module
      | module.child["a"]      | ModuleCallInstance     | module.child["a"]            |                    |
      | module.child["a"].out  | ModuleCallInstanceOutput | module.child["a"].out        |                    | # Output from indexed module
      # Actions
      | action.foo.bar         | Action                 | action.foo.bar               |                    |
      | action.foo.bar[1]      | ActionInstance         | action.foo.bar[1]            |                    |

  Scenario Outline: Parsing Invalid References in Standard Scope
    Given an HCL traversal string "<TraversalString>" in a standard scope
    When it is parsed as a reference
    Then the parsing should fail with an error containing "<ExpectedErrorMessage>"

    Examples:
      | TraversalString        | ExpectedErrorMessage                                                                 |
      | var                    | The "var" object cannot be accessed directly.                                        |
      | local["foo"]           | The "local" object does not support this operation.                                  |
      | count                  | The "count" object cannot be accessed directly.                                      |
      | each["key"]            | The "each" object does not support this operation.                                   |
      | data                   | The "data" object must be followed by two attribute names                            |
      | data.aws_ami           | The "data" object must be followed by two attribute names                            |
      | module                 | The "module" object cannot be accessed directly.                                     |
      | path["cwd"]            | The "path" object does not support this operation.                                   |
      | terraform              | The "terraform" object cannot be accessed directly.                                  |
      | boop_instance          | A reference to a resource type must be followed by at least one attribute access     |
      | template.foo           | The symbol name "template" is reserved for use in a future Terraform version.        |
      | action                 | The "action" object must be followed by two attribute names                          |
      | action.foo             | The "action" object must be followed by two attribute names                          |

  Scenario Outline: Parsing Valid References in Testing Scope (terraform test)
    Given an HCL traversal string "<TraversalString>" in a testing scope
    When it is parsed as a reference
    Then the parsing should be successful
    And the reference subject should be a "<SubjectType>" representing "<SubjectAddress>"
    And the remaining traversal should be "<RemainingTraversal>"

    Examples:
      | TraversalString | SubjectType | SubjectAddress | RemainingTraversal |
      | output.value    | OutputValue | output.value   |                    |
      | check.health    | Check       | check.health   |                    |
      | run.zero        | Run         | run.zero       |                    |
      | run.zero.value  | Run         | run.zero       | .value             |
      | count.index     | CountAttr   | count.index    |                    | # Fallback to standard parsing

  Scenario Outline: Parsing Invalid References in Testing Scope (terraform test)
    Given an HCL traversal string "<TraversalString>" in a testing scope
    When it is parsed as a reference
    Then the parsing should fail with an error containing "<ExpectedErrorMessage>"

    Examples:
      | TraversalString | ExpectedErrorMessage                                                                 |
      | output          | The "output" object cannot be accessed directly.                                     |
      | output["foo"]   | The "output" object does not support this operation.                                 |
      | check           | The "check" object cannot be accessed directly.                                      |
      | run["foo"]      | The "run" object does not support this operation.                                    |

```

Notes on this Gherkin:

*   `<SubjectAddress>` is a simplified string representation of the expected subject. The step definition will need to construct the actual expected `Referenceable` object (e.g., `addrs.InputVariable{Name: "foo"}`).
*   `<RemainingTraversal>` being empty means no further traversal. If present (e.g., ".blah"), it implies an `hcl.Traversal` with those steps.
*   The distinction between "Standard Scope" and "Testing Scope" is made explicit in the scenarios.
*   For `ResourceInstance` subjects where the key is implicit (e.g., `aws_instance.web.id`), the `SubjectAddress` indicates the resource part (`aws_instance.web`) and the key is implied as `NoKey` by the parser before the remaining traversal.
*   This Gherkin aims to cover the different *types* of references and common error patterns rather than every single test case.

The next file is `internal/addrs/parse_target_test.go`.
