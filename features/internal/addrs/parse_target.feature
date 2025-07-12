# Metadata:
# Covers: internal/addrs/parse_target_test.go
# TestFunctions:
# - TestParseTarget

Feature: Parsing Target Addresses for CLI Operations
  This feature describes how Terraform parses address strings provided for
  targeting operations (e.g., via the -target flag) into specific
  ModuleInstance, AbsoluteResource, or AbsoluteResourceInstance addresses.

  Scenario Outline: Parsing Valid Target Addresses
    Given a target address string "<TargetString>"
    When it is parsed as a target
    Then the parsing should be successful
    And the resulting target subject should be an <ExpectedSubjectType>
    And its string representation should be "<ExpectedSubjectString>"

    Examples:
      # Module Instances
      | TargetString                     | ExpectedSubjectType   | ExpectedSubjectString                                  |
      | module.foo                       | ModuleInstance        | module.foo                                             |
      | module.foo[2]                    | ModuleInstance        | module.foo[2]                                          |
      | module.foo[2].module.bar         | ModuleInstance        | module.foo[2].module.bar                               |
      # Absolute Resources (Managed)
      | aws_instance.foo                 | AbsResource           | aws_instance.foo                                       |
      | resource.aws_instance.foo        | AbsResource           | aws_instance.foo                                       | # Explicit 'resource.' prefix
      | module.foo.aws_instance.bar      | AbsResource           | module.foo.aws_instance.bar                            |
      # Absolute Resource Instances (Managed)
      | aws_instance.foo[1]              | AbsResourceInstance   | aws_instance.foo[1]                                    |
      | module.foo.module.bar.aws_instance.baz["hello"] | AbsResourceInstance | module.foo.module.bar.aws_instance.baz["hello"]    |
      # Absolute Resources (Data)
      | data.aws_instance.foo            | AbsResource           | data.aws_instance.foo                                  |
      | module.foo.data.aws_instance.bar | AbsResource           | module.foo.data.aws_instance.bar                       |
      # Absolute Resource Instances (Data)
      | data.aws_instance.foo[1]         | AbsResourceInstance   | data.aws_instance.foo[1]                               |
      | module.foo.module.bar["a"].data.aws_instance.baz["hello"] | AbsResourceInstance | module.foo.module.bar["a"].data.aws_instance.baz["hello"] |
      # Absolute Resources (Ephemeral)
      | ephemeral.aws_instance.foo       | AbsResource           | ephemeral.aws_instance.foo                             |
      # Absolute Resource Instances (Ephemeral)
      | ephemeral.aws_instance.foo[1]    | AbsResourceInstance   | ephemeral.aws_instance.foo[1]                          |


  Scenario Outline: Parsing Invalid Target Addresses
    Given a target address string "<TargetString>"
    When it is parsed as a target
    Then the parsing should fail with an error containing "<ExpectedErrorMessage>"

    Examples:
      | TargetString               | ExpectedErrorMessage                                                                 |
      | aws_instance               | Resource specification must include a resource type and name.                        |
      | module                     | Prefix "module." must be followed by a module name.                                  |
      | module["baz"]              | Prefix "module." must be followed by a module name.                                  |
      | module.baz.bar             | Resource specification must include a resource type and name.                        | # Interpreted as module.baz trying to contain resource 'bar' without type
      | aws_instance.foo.bar       | Resource instance key must be given in square brackets.                              | # '.bar' is not a valid key format
      | aws_instance.foo[1].baz    | Unexpected extra operators after address.                                            |
      | each.key                   | The keyword "each" is reserved and cannot be used to target a resource address.      |
      | count.index                | The keyword "count" is reserved and cannot be used to target a resource address.     |
      | local.value                | The keyword "local" is reserved and cannot be used to target a resource address.     |
      | path.root                  | The keyword "path" is reserved and cannot be used to target a resource address.      |
      | self.id                    | The keyword "self" is reserved and cannot be used to target a resource address.      |
      | terraform.planning         | The keyword "terraform" is reserved and cannot be used to target a resource address. |
      | var.foo                    | The keyword "var" is reserved and cannot be used to target a resource address.       |
      | template                   | The keyword "template" is reserved and cannot be used to target a resource address.  |

```

Notes on this Gherkin:

*   The `ExpectedSubjectString` should match the string representation of the parsed subject (e.g., `ModuleInstance.String()`, `AbsResource.String()`, `AbsResourceInstance.String()`).
*   The examples cover the main valid forms (module instance, resource collection, specific resource instance for managed/data/ephemeral) and a selection of common error cases, especially those involving reserved keywords or malformed addresses.
*   The distinction between `AbsResource` (the whole set of instances) and `AbsResourceInstance` (a specific one, possibly with an index/key) is important for targeting.

The next file to process is `internal/addrs/partial_expanded_test.go`.
