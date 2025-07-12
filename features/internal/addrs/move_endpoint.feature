# Metadata:
# Covers: internal/addrs/move_endpoint_test.go
# TestFunctions:
# - TestParseMoveEndpoint
# - TestUnifyMoveEndpoints
# - TestMoveEndpointConfigMoveable

Feature: Parsing and Processing of Move Endpoints
  This feature describes how Terraform parses address strings used in 'moved' blocks
  into internal move endpoint representations, how these endpoints are unified,
  and how they are converted to configuration-level moveable addresses.

  Scenario Outline: Parsing Valid Move Endpoint Addresses
    Given an address string "<AddressString>" for a move endpoint
    When the address string is parsed
    Then the operation should be successful
    And the resulting move endpoint's relative subject should be an <ExpectedType>
    And its string representation should match the structure of "<ExpectedSubjectStructure>"

    Examples:
      # Managed Resources
      | AddressString                 | ExpectedType          | ExpectedSubjectStructure         |
      | foo.bar                       | AbsResourceInstance   | resource.foo.bar                 |
      | foo.bar[0]                    | AbsResourceInstance   | resource.foo.bar[0]              |
      | foo.bar["a"]                  | AbsResourceInstance   | resource.foo.bar["a"]            |
      | module.boop.foo.bar           | AbsResourceInstance   | module.boop.resource.foo.bar     |
      | module.boop.foo.bar[0]        | AbsResourceInstance   | module.boop.resource.foo.bar[0]  |
      # Data Resources
      | data.foo.bar                  | AbsResourceInstance   | data.foo.bar                     |
      | data.foo.bar[0]               | AbsResourceInstance   | data.foo.bar[0]                  |
      | module.boop.data.foo.bar      | AbsResourceInstance   | module.boop.data.foo.bar         |
      # Module Instances
      | module.foo                    | ModuleInstance        | module.foo                       |
      | module.foo[0]                 | ModuleInstance        | module.foo[0]                    |
      | module.foo["a"]               | ModuleInstance        | module.foo["a"]                  |
      | module.foo[1].module.bar      | ModuleInstance        | module.foo[1].module.bar         |

  Scenario Outline: Parsing Invalid Move Endpoint Addresses
    Given an address string "<AddressString>" for a move endpoint
    When the address string is parsed
    Then the operation should fail with an error containing "<ExpectedErrorMessage>"

    Examples:
      | AddressString          | ExpectedErrorMessage                                               |
      | module                 | Prefix "module." must be followed by a module name.                |
      | module[0]              | Prefix "module." must be followed by a module name.                |
      | module.foo.data        | Resource specification must include a resource type and name.      |
      | module.foo.data.bar    | Resource specification must include a resource type and name.      | # Missing type for 'bar'
      | module.foo.data[0]     | Resource specification must include a resource type and name.      |
      | module.foo.data.bar[0] | A resource name is required.                                       | # 'bar' is type, name missing
      | module.foo.bar         | Resource specification must include a resource type and name.      | # 'bar' could be type or name, ambiguous without context
      | module.foo.bar[0]      | A resource name is required.                                       | # 'bar' is type, name missing

  Scenario Outline: Unifying From and To Move Endpoints
    Given a 'moved' block declared in module context "<DeclModulePath>"
    And a 'from' endpoint parsed from address "<FromAddrStr>"
    And a 'to' endpoint parsed from address "<ToAddrStr>"
    When the 'from' and 'to' endpoints are unified
    Then the string representation of the unified 'from' endpoint should be "<UnifiedFromStr>"
    And the string representation of the unified 'to' endpoint should be "<UnifiedToStr>"

    Examples:
      # Resource to Resource in Root
      | DeclModulePath | FromAddrStr      | ToAddrStr        | UnifiedFromStr | UnifiedToStr   |
      |                | foo.bar          | foo.baz          | foo.bar[*]     | foo.baz[*]     |
      # Resource to Resource in Child Module
      | module.a       | foo.bar          | foo.baz          | module.a[*].foo.bar[*] | module.a[*].foo.baz[*] |
      # Resource to Resource in different module path (relative 'to')
      | module.a       | foo.bar          | module.b[0].foo.baz | module.a[*].foo.bar[*] | module.a[*].module.b[0].foo.baz[*] |
      # Resource to specific Resource Instance
      |                | foo.bar          | foo.bar["thing"] | foo.bar        | foo.bar["thing"] |
      # Specific Resource Instance to Resource
      |                | foo.bar["thing"] | foo.bar          | foo.bar["thing"] | foo.bar        |
      # Module to Module in Root
      |                | module.foo       | module.bar       | module.foo[*]  | module.bar[*]  |
      # Module to Module in Child Module
      | module.bloop   | module.foo       | module.bar.module.baz | module.bloop[*].module.foo[*] | module.bloop[*].module.bar.module.baz[*] |
      # Specific Module Instance to Specific Module Instance
      |                | module.foo[0]    | module.foo["a"]  | module.foo[0]  | module.foo["a"]  |
      # Module to Specific Module Instance
      |                | module.foo       | module.foo["a"]  | module.foo     | module.foo["a"]  |
      # Unification failure: Module to Resource
      |                | module.foo       | foo.bar          |                |                | # Empty strings indicate failure/nil
      |                | module.foo[0]    | foo.bar          |                |                |

  Scenario Outline: Converting Move Endpoint to ConfigMoveable Address
    Given a move endpoint parsed from address "<EndpointAddrStr>"
    And the context module for configuration is "<ConfigModulePath>"
    When the move endpoint is converted to a ConfigMoveable address
    Then the resulting ConfigMoveable address should be of type <ExpectedConfigType>
    And its string representation should be "<ExpectedConfigAddrStr>"

    Examples:
      # Resource in Root
      | EndpointAddrStr      | ConfigModulePath | ExpectedConfigType | ExpectedConfigAddrStr |
      | foo.bar              |                  | ConfigResource     | resource.foo.bar      |
      | foo.bar[0]           |                  | ConfigResource     | resource.foo.bar      | # Instance key stripped
      # Resource in Module (endpoint is absolute)
      | module.foo.bar.baz   |                  | ConfigResource     | module.foo.resource.bar.baz |
      # Resource in Module (endpoint is relative to config module)
      | foo.bar              | module.boop      | ConfigResource     | module.boop.resource.foo.bar |
      # Module in Root
      | module.foo           |                  | Module             | module.foo            |
      | module.foo[0]        |                  | Module             | module.foo            | # Instance key stripped
      # Module in Module (endpoint is relative to config module)
      | module.bloop         | module.bleep     | Module             | module.bleep.module.bloop |

```

Notes for this Gherkin:

*   For `ParseMoveEndpoint`, `ExpectedSubjectStructure` is a simplified representation. For example, `resource.foo.bar` implies an `AbsResourceInstance` with type "foo", name "bar", and `NoKey`. The step definition would need to construct the full expected object for comparison.
*   In `UnifyMoveEndpoints`, an empty string for `UnifiedFromStr` or `UnifiedToStr` signifies that the unification failed (returned nil), as per the test logic for incompatible types.
*   `ConfigModulePath` being empty implies the root module.
*   The term "resource." prefix (e.g. `resource.foo.bar`) in `ExpectedConfigAddrStr` is how `ConfigResource.String()` typically renders.
*   This Gherkin captures the essence of the transformations and validations. The underlying step definitions would handle the detailed parsing and object constructions.

The next file in `internal/addrs/` is `output_value_test.go`.
