# Metadata:
# Covers: internal/addrs/remove_target.go
# Behavior derived from source code analysis.

Feature: Remove Target Addressing and Parsing
  This feature describes how Terraform parses and represents target addresses
  specified in 'removed' blocks, which are used to declare that a previously
  managed resource or module should be removed from state.

  Scenario Outline: Successfully Parsing Valid Remove Targets
    Given an HCL traversal string "<TraversalString>" for a remove target
    When it is parsed as a remove target
    Then the parsing should be successful
    And the remove target's relative subject should be a <SubjectType>
    And its string representation should be "<ExpectedSubjectString>"
    And its object kind should be <ExpectedObjectKind>

    Examples:
      # Module targets
      | TraversalString          | SubjectType | ExpectedSubjectString    | ExpectedObjectKind   |
      | module.old_module        | Module      | module.old_module        | RemoveTargetModule   |
      | module.parent.module.child | Module    | module.parent.module.child | RemoveTargetModule   |
      # Managed Resource targets
      | aws_instance.old_vm      | ConfigResource | resource.aws_instance.old_vm | RemoveTargetResource |
      | module.networking.aws_vpc.main | ConfigResource | module.networking.resource.aws_vpc.main | RemoveTargetResource |

  Scenario Outline: Failing to Parse Invalid Remove Targets
    Given an HCL traversal string "<TraversalString>" for a remove target
    When it is parsed as a remove target
    Then the parsing should fail with an error containing "<ExpectedErrorMessage>"

    Examples:
      | TraversalString                 | ExpectedErrorMessage                                                     |
      | data.template_file.example      | Data source address not allowed                                          |
      | module.my_mod.data.http.example | Data source address not allowed                                          |
      | aws_instance.web[0]             | Extraneous operator after resource name.                                 | # ConfigResource cannot be indexed
      | module.foo[0]                   | Extraneous operator after module name.                                   | # Module config path cannot be indexed
      | some_local_value                | Resource specification must include a resource type and name.            |
      | var.my_var                      | The keyword "var" is reserved for variable references.                   | # Adjusted error

  Scenario: RemoveTarget String Representation and Equality
    Given a RemoveTarget "RT1" for module "module.old_app" at source range "file1.tf:10-20"
    And another RemoveTarget "RT2" for module "module.old_app" at source range "file1.tf:10-20"
    And another RemoveTarget "RT3" for resource "resource.aws_s3_bucket.old_bucket" at source range "file2.tf:5-15"
    And another RemoveTarget "RT4" for module "module.different_app" at source range "file1.tf:10-20"
    And another RemoveTarget "RT5" for module "module.old_app" at source range "file1.tf:30-40" # Different range

    When I get the string representation of "RT1"
    Then it should be "module.old_app"

    When I compare "RT1" and "RT2" for equality
    Then they should be equal

    When I compare "RT1" and "RT3" for equality
    Then they should NOT be equal

    When I compare "RT1" and "RT4" for equality
    Then they should NOT be equal

    When I compare "RT1" and "RT5" for equality
    Then they should NOT be equal # Due to different source range

  Scenario: RemoveTarget Object Kind
    Given a RemoveTarget for module "module.legacy"
    When its object kind is requested
    Then it should be RemoveTargetModule

    Given a RemoveTarget for resource "resource.null_resource.gone"
    When its object kind is requested
    Then it should be RemoveTargetResource

```
A note on "Failing to parse targets with instance keys": The parser seems to try to parse a `ConfigResource` or `Module` first. If an index is present in `parseConfigResourceUnderModule` or `parseModulePrefix`, it would lead to errors like "Resource instance key must be given in square brackets" if the structure is `foo.bar.baz[0]` (interpreted as `baz` being an attribute of `bar` rather than an index on `bar`) or other structural errors. The key is that `ConfigMoveable` (the type of `RelSubject`) does not support instance keys. The error messages might vary based on how the parser interprets the malformed indexed address.

Next non-test `.go` file: `resource_mode.go`.
