# Source Go File: internal/addrs/parse_ref.go
# Source Go Test: internal/addrs/parse_ref_test.go

Feature: Parsing HCL Traversal to Terraform Reference
  This feature describes how HCL traversals are parsed into Terraform-specific
  Reference (addrs.Reference) objects, which represent references to various
  addressable items like resources, variables, locals, module outputs, etc.

  Background:
    Given the Terraform addressing system for references

  Scenario Outline: Parsing valid HCL traversals to References
    Given an HCL traversal string "<TraversalString>"
    When ParseRef (or ParseRefFromTestingScope for testing-only keywords) is called with the parsed traversal
    Then the resulting Reference's Subject should be of type <ExpectedSubjectType> with name "<SubjectName>" (and type "<ResourceType>" if applicable)
    And its SourceRange should cover the input string
    And if <RemainingTraversal> is not empty, the Reference's Remaining traversal should represent "<RemainingTraversal>"
    And no parsing error should occur

    Examples:
      | TraversalString             | ExpectedSubjectType        | SubjectName | ResourceType    | RemainingTraversal |
      | count.index                 | CountAttr                  | "index"     |                 | ""                 |
      | each.key                    | ForEachAttr                | "key"       |                 | ""                 |
      | data.external.foo           | Resource                   | "foo"       | "external"      | ""                 | # Mode: DataResourceMode
      | data.external.foo.bar       | ResourceInstance           | "foo"       | "external"      | ".bar"             |
      | data.external.foo["baz"]    | ResourceInstance           | "foo"       | "external"      | ""                 | # Key: StringKey("baz")
      | data.external.foo["baz"].bar| ResourceInstance           | "foo"       | "external"      | ".bar"             | # Key: StringKey("baz")
      | ephemeral.external.foo      | Resource                   | "foo"       | "external"      | ""                 | # Mode: EphemeralResourceMode
      | local.foo                   | LocalValue                 | "foo"       |                 | ""                 |
      | local.foo.blah              | LocalValue                 | "foo"       |                 | ".blah"            |
      | local.foo["blah"]           | LocalValue                 | "foo"       |                 | "[\"blah\"]"       |
      | module.foo                  | ModuleCall                 | "foo"       |                 | ""                 |
      | module.foo.bar              | ModuleCallInstanceOutput   | "foo"       |                 | ""                 | # Output name "bar"
      | module.foo["baz"]           | ModuleCallInstance         | "foo"       |                 | ""                 | # Key: StringKey("baz")
      | module.foo["baz"].bar       | ModuleCallInstanceOutput   | "foo"       |                 | ""                 | # Key: StringKey("baz"), Output "bar"
      | path.module                 | PathAttr                   | "module"    |                 | ""                 |
      | self                        | Self                       |             |                 | ""                 |
      | self.blah                   | Self                       |             |                 | ".blah"            |
      | terraform.workspace         | TerraformAttr              | "workspace" |                 | ""                 |
      | var.foo                     | InputVariable              | "foo"       |                 | ""                 |
      | resource.boop_instance.foo  | Resource                   | "foo"       | "boop_instance" | ""                 | # Mode: ManagedResourceMode
      | boop_instance.foo           | Resource                   | "foo"       | "boop_instance" | ""                 | # Mode: ManagedResourceMode
      | boop_instance.foo["baz"]    | ResourceInstance           | "foo"       | "boop_instance" | ""                 | # Key: StringKey("baz")
      | action.foo.bar              | Action                     | "bar"       | "foo"           | ""                 | # Type "foo"
      | action.foo.bar[1]           | ActionInstance             | "bar"       | "foo"           | ""                 | # Key: IntKey(1)
      # Testing scope specific
      | output.value                | OutputValue                | "value"     |                 | ""                 | # ParseRefFromTestingScope
      | check.health                | Check                      | "health"    |                 | ""                 | # ParseRefFromTestingScope
      | run.zero                    | Run                        | "zero"      |                 | ""                 | # ParseRefFromTestingScope
      | run.zero.value              | Run                        | "zero"      |                 | ".value"           | # ParseRefFromTestingScope

  Scenario Outline: Parsing invalid HCL traversals for References
    Given an HCL traversal string "<TraversalString>"
    When ParseRef (or ParseRefFromTestingScope) is called with the parsed traversal
    Then an error should occur with a detail message containing "<ExpectedErrorMessageSubstring>"

    Examples:
      | TraversalString        | ExpectedErrorMessageSubstring                                                                |
      | count                  | The "count" object cannot be accessed directly.                                              |
      | count["hello"]         | The "count" object does not support this operation.                                          |
      | each                   | The "each" object cannot be accessed directly.                                               |
      | data                   | The "data" object must be followed by two attribute names                                    |
      | data.external          | The "data" object must be followed by two attribute names                                    |
      | ephemeral              | The "ephemeral" object must be followed by two attribute names                               |
      | local                  | The "local" object cannot be accessed directly.                                              |
      | module                 | The "module" object cannot be accessed directly.                                             |
      | path                   | The "path" object cannot be accessed directly.                                               |
      | terraform              | The "terraform" object cannot be accessed directly.                                          |
      | var                    | The "var" object cannot be accessed directly.                                                |
      | boop_instance          | A reference to a resource type must be followed by at least one attribute access             |
      | template.foo           | The symbol name "template" is reserved                                                       |
      | action                 | The "action" object must be followed by two attribute names                                  |
      | output                 | The "output" object cannot be accessed directly.                                             | # ParseRefFromTestingScope
      | check                  | The "check" object cannot be accessed directly.                                              | # ParseRefFromTestingScope
      | run                    | The "run" object cannot be accessed directly.                                                | # ParseRefFromTestingScope

  # Note:
  # - ExpectedSubjectType refers to the Go type of the `Subject` field in `addrs.Reference`.
  # - SubjectName is the `Name` field of the subject type (e.g., Resource.Name, LocalValue.Name).
  # - ResourceType is the `Type` field for Resource subjects.
  # - RemainingTraversal is the HCL traversal part that was not consumed in forming the Subject.
  # - InstanceKeys (like IntKey, StringKey) are part of ResourceInstance and ModuleCallInstance subjects.
  # - The cty aspects are primarily how InstanceKey (which can wrap cty.Value) is parsed and stored,
  #   and how HCL traversals (which can include cty.Value index keys) are processed.
  # - Step definitions will need to parse traversal strings into hcl.Traversal and then call the appropriate ParseRef function.
  # - SourceRange checking is simplified to "covers the input string" but in reality, it's more precise.
  # - Some keywords like "output", "check", "run" are only valid in the "testing scope" via ParseRefFromTestingScope.
  #   Others like "resource" (as a prefix) are handled by the main ParseRef.
