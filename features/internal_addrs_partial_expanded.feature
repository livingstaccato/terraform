# Source Go File: internal/addrs/partial_expanded.go
# Source Go Test: internal/addrs/partial_expanded_test.go

Feature: Partially Expanded Addresses for Modules and Resources
  This feature describes how Terraform parses and handles partially expanded
  addresses, which can occur during plan generation when parts of a module or
  resource address might still contain unknown instance keys (represented by '*').
  It also covers how these partial addresses are checked against target addresses.

  Background:
    Given the Terraform addressing system

  Scenario Outline: Checking if a PartialExpandedResource is targeted
    Given a PartialExpandedResource parsed from "<PartialResourceAddrString>"
    And a Target address parsed from "<TargetAddrString>"
    When the PartialExpandedResource's IsTargetedBy method is called with the Target
    Then the result should be <IsTargeted>

    Examples:
      | PartialResourceAddrString | TargetAddrString            | IsTargeted |
      | test.a                    | test.a                      | true       |
      | test.a                    | test.a[0]                   | true       |
      | test.a[*]                 | test.a                      | true       |
      | test.a[*]                 | test.a[0]                   | true       |
      | test.a[*]                 | test.a["key"]               | true       |
      | module.mod.test.a         | module.mod.test.a           | true       |
      | module.mod[1].test.a      | module.mod[0].test.a        | false      | # Different module instance key
      | module.mod.test.a[*]      | module.mod.test.a           | true       |
      | module.mod.test.a[*]      | module.mod.test.a[0]        | true       |
      | module.mod.test.a[*]      | module.mod[0].test.a        | false      | # Module instance key known in target, not matching wildcard context
      | module.mod[*].test.a      | module.mod.test.a           | true       |
      | module.mod[*].test.a      | module.mod[0].test.a        | true       |
      | module.mod[*].test.a      | module.mod["key"].test.a    | true       |

  Scenario Outline: Parsing HCL traversal to PartialExpandedModule
    Given an HCL traversal representing "<AddrString>"
      # For unknown keys, the traversal is constructed with cty.UnknownVal(cty.Number/String) for the index key
    When ParsePartialExpandedModule is called with this traversal
    Then the resulting PartialExpandedModule should have expanded prefix "<ExpectedExpandedPrefix>"
    And its unexpanded suffix should be "<ExpectedUnexpandedSuffix>"
    And the number of remaining traversal steps should be <ExpectedRemainingSteps>
    And no parsing error should occur

    Examples:
      # AddrString, ExpectedExpandedPrefix, ExpectedUnexpandedSuffix, ExpectedRemainingSteps
      | module.mod                                                             | module.mod          | ""                  | 0 |
      | module.mod[*] (from module.mod[UNKNOWN_KEY])                           | ""                  | module.mod          | 0 |
      | module.child.module.grandchild                                         | module.child.module.grandchild | ""                  | 0 |
      | module.child[0].module.grandchild                                      | module.child[0].module.grandchild | ""                  | 0 |
      | module.child[*].module.grandchild (from module.child[UK].module.grandchild) | ""                  | module.child.module.grandchild | 0 |
      | module.child.module.grandchild[*] (from module.child.module.grandchild[UK])| module.child        | module.grandchild   | 0 |
      | module.child.module.grandchild[*].resource_type.resource_name (from ...[UK]...) | module.child        | module.grandchild   | 2 | # resource_type.resource_name are remaining

  Scenario Outline: Parsing HCL traversal to PartialExpandedResource
    Given an HCL traversal string "<AddrString>"
    When ParsePartialExpandedResource is called with the parsed traversal
    Then the resulting PartialExpandedResource should have expanded module prefix "<ExpectedModuleExpandedPrefix>"
    And unexpanded module suffix "<ExpectedModuleUnexpandedSuffix>"
    And its resource part should be "<ExpectedResourceString>" (Mode, Type, Name)
    And the number of remaining traversal steps should be <ExpectedRemainingSteps>
    And no parsing error should occur

    Examples:
      # AddrString, ExpectedModuleExpandedPrefix, ExpectedModuleUnexpandedSuffix, ExpectedResourceString, ExpectedRemainingSteps
      | resource_type.resource_name        | ""                  | ""                  | resource_type.resource_name        | 0 |
      | module.mod.resource_type.resource_name | module.mod          | ""                  | resource_type.resource_name        | 0 |
      | resource_type.resource_name[0]     | ""                  | ""                  | resource_type.resource_name        | 0 | # Index dropped for resource part
      | resource_type.resource_name[0].attr| ""                  | ""                  | resource_type.resource_name        | 1 | # .attr is remaining
      | resource.resource_type.resource_name | ""                  | ""                  | resource_type.resource_name        | 0 | # "resource." prefix handled

  # Note:
  # - PartialExpandedResource/Module split an address into an "expanded" prefix (with known instance keys)
  #   and an "unexpanded" suffix (module path where the first unknown key was encountered, or the resource itself).
  # - [*] in addresses like "module.mod[*]" or "test.a[*]" denotes that the instance key is unknown or a wildcard for targeting.
  # - Step definitions will need to parse address strings into the respective `addrs` types.
  # - For ParsePartialExpandedModule/Resource, constructing HCL traversals with cty.UnknownVal for indices is key for some test cases.
  # - The cty aspects are central here, as unknown cty.Values in instance keys drive the "partial" expansion logic.
  # - EffectiveAddrString is the string representation of the parsed subject.
  # - Resource string includes mode (default Managed), type, and name.
  # - Remaining steps are parts of the traversal after the resource/module address itself.
