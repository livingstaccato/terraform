# Metadata:
# Covers: internal/addrs/partial_expanded_test.go
# TestFunctions:
# - TestPartialExpandedResourceIsTargetedBy
# - TestParsePartialExpandedModule
# - TestParsePartialExpandedResource

Feature: Partially Expanded Addresses and Targeting
  This feature describes how Terraform handles and parses addresses that may be
  partially expanded (e.g., containing wildcards or representing unexpanded for_each/count items)
  and how these partial addresses interact with targeting logic.

  Scenario Outline: Checking if a Partial Expanded Resource is Targeted
    Given a partial expanded resource address "<PartialResourceAddr>"
    And a target address "<TargetAddr>"
    When I check if the partial expanded resource is targeted by the target address
    Then the result should be <IsTargeted>

    Examples:
      # Exact match
      | PartialResourceAddr      | TargetAddr               | IsTargeted |
      | test.a                   | test.a                   | true       |
      # Partial targets whole resource, target is specific instance
      | test.a                   | test.a[0]                | true       |
      # Partial has wildcard key, target is whole resource
      | test.a[*]                | test.a                   | true       |
      # Partial has wildcard key, target is specific instance
      | test.a[*]                | test.a[0]                | true       |
      | test.a[*]                | test.a["key"]            | true       |
      # Module paths
      | module.mod.test.a        | module.mod.test.a        | true       |
      | module.mod[1].test.a     | module.mod[0].test.a     | false      | # Different module instance keys
      | module.mod.test.a[*]     | module.mod.test.a[0]     | true       |
      | module.mod.test.a[*]     | module.mod[0].test.a     | false      | # Module path mismatch before wildcard
      # Module path with wildcard
      | module.mod[*].test.a     | module.mod.test.a        | true       | # Target has no key for mod
      | module.mod[*].test.a     | module.mod[0].test.a     | true       | # Target has specific key for mod
      | module.mod[*].test.a     | module.mod["key"].test.a | true       |

  Scenario Outline: Parsing Partially Expanded Module Addresses
    Given an HCL traversal representing the module address "<TraversalString>"
    When it is parsed as a partially expanded module
    Then the parsing should be successful
    And the expanded prefix of the module should be "<ExpandedPrefix>"
    And the unexpanded suffix of the module should be "<UnexpandedSuffix>"
    And the number of remaining traversal steps should be <RemainingSteps>

    Examples:
      # Fully expanded
      | TraversalString                     | ExpandedPrefix              | UnexpandedSuffix | RemainingSteps |
      | module.mod                          | module.mod                  |                  | 0              |
      | module.child.module.grandchild      | module.child.module.grandchild |                  | 0              |
      | module.child[0].module.grandchild   | module.child[0].module.grandchild |                | 0              |
      # Partially expanded (wildcard introduced by unknown value)
      | module.mod[*]                       |                             | module.mod       | 0              | # Conceptually, if mod's key is unknown
      | module.child[*].module.grandchild   |                             | module.child.module.grandchild | 0 |
      | module.child.module.grandchild[*]   | module.child                | module.grandchild| 0              |
      # With remaining resource traversal
      | module.child.module.grandchild[*].resource_type.resource_name | module.child | module.grandchild | 2 | # "resource_type", "resource_name" remain

  Scenario Outline: Parsing Partially Expanded Resource Addresses
    Given an HCL traversal representing the resource address "<TraversalString>"
    When it is parsed as a partially expanded resource
    Then the parsing should be successful
    And the expanded module prefix should be "<ExpandedModulePrefix>"
    And the unexpanded module suffix should be "<UnexpandedModuleSuffix>"
    And the resource type should be "<ResourceType>" and name "<ResourceName>"
    And the resource mode should be "<ResourceMode>"
    And the number of remaining traversal steps should be <RemainingSteps>

    Examples:
      # Simple resource
      | TraversalString                     | ExpandedModulePrefix | UnexpandedModuleSuffix | ResourceType  | ResourceName  | ResourceMode | RemainingSteps |
      | resource_type.resource_name         |                      |                        | resource_type | resource_name | Managed      | 0              |
      | module.mod.resource_type.resource_name | module.mod          |                        | resource_type | resource_name | Managed      | 0              |
      # Resource with instance key (key is part of remaining for partial resource parsing)
      | resource_type.resource_name[0]      |                      |                        | resource_type | resource_name | Managed      | 0              | # Key is consumed by ParsePartialExpandedResource for the resource itself
      # Resource with attribute traversal
      | resource_type.resource_name[0].attr |                      |                        | resource_type | resource_name | Managed      | 1              | # ".attr" remains
      # Explicit "resource." prefix
      | resource.resource_type.resource_name|                      |                        | resource_type | resource_name | Managed      | 0              |

```

Notes for this Gherkin:

*   For `TestPartialExpandedResourceIsTargetedBy`, the `<PartialResourceAddr>` might contain `[*]` to denote the wildcard/unexpanded part, as per the test case structure.
*   For `TestParsePartialExpandedModule` and `TestParsePartialExpandedResource`, the `<TraversalString>` represents the conceptual address being parsed. The actual Go tests construct these traversals programmatically with `cty.UnknownVal` in some cases. The Gherkin simplifies this to a string representation.
    *   `ExpandedPrefix` and `UnexpandedSuffix` being empty signifies no such part.
    *   `<RemainingSteps>` indicates how many HCL traversal steps are left over after parsing the partial module/resource part.
*   The "ResourceMode" is added to the resource parsing scenario for completeness, as `Resource` struct contains it.
*   The Gherkin tries to capture the essence of splitting an address into known (expanded) and unknown/yet-to-be-expanded parts.

The next file in `internal/addrs/` is `provider_config_test.go`.
