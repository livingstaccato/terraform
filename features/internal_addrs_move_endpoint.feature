# Source Go File: internal/addrs/move_endpoint.go
# Source Go Test: internal/addrs/move_endpoint_test.go

Feature: Move Endpoint Parsing and Unification
  This feature describes how Terraform parses HCL traversals into MoveEndpoint
  objects and how these endpoints are unified based on the module in which a
  `moved` block is declared.

  Background:
    Given the Terraform addressing system for `moved` blocks

  Scenario Outline: Parsing HCL traversal to MoveEndpoint
    Given an HCL traversal string "<TraversalString>"
    When ParseMoveEndpoint is called with the parsed traversal
    Then the resulting MoveEndpoint's relative subject should be an <ExpectedSubjectType>
    And its string representation should effectively be "<EffectiveAddrString>"
    And no parsing error should occur

    Examples:
      | TraversalString             | ExpectedSubjectType   | EffectiveAddrString         |
      | foo.bar                     | AbsResourceInstance   | foo.bar                     |
      | foo.bar[0]                  | AbsResourceInstance   | foo.bar[0]                  |
      | foo.bar["a"]                | AbsResourceInstance   | foo.bar["a"]                |
      | module.boop.foo.bar         | AbsResourceInstance   | module.boop.foo.bar         |
      | data.foo.bar                | AbsResourceInstance   | data.foo.bar                |
      | module.foo                  | ModuleInstance        | module.foo                  |
      | module.foo[0]               | ModuleInstance        | module.foo[0]               |
      | module.foo.module.bar       | ModuleInstance        | module.foo.module.bar       |

  Scenario Outline: Parsing invalid HCL traversal for MoveEndpoint
    Given an HCL traversal string "<TraversalString>"
    When ParseMoveEndpoint is called with the parsed traversal
    Then an error should occur with a message containing "<ExpectedErrorMessageSubstring>"

    Examples:
      | TraversalString        | ExpectedErrorMessageSubstring                                           |
      | module                 | Prefix "module." must be followed by a module name.                     |
      | module[0]              | Prefix "module." must be followed by a module name.                     |
      | module.foo.data        | Resource specification must include a resource type and name.           |
      | module.foo.data.bar[0] | A resource name is required.                                            | # After data.bar
      | module.foo.bar         | Resource specification must include a resource type and name.           | # If "bar" is not a type

  Scenario Outline: Unifying MoveEndpoints based on declaration module
    Given a `moved` block declared in module "<DeclModulePath>"
    And the `from` address in the `moved` block is parsed from "<FromInput>"
    And the `to` address in the `moved` block is parsed from "<ToInput>"
    When UnifyMoveEndpoints is called
    Then the resulting unified 'from' endpoint string should be "<ExpectedUnifiedFromString>"
    And the resulting unified 'to' endpoint string should be "<ExpectedUnifiedToString>"

    Examples:
      | DeclModulePath | FromInput          | ToInput               | ExpectedUnifiedFromString        | ExpectedUnifiedToString           |
      | ""             | foo.bar            | foo.baz               | foo.bar[*]                       | foo.baz[*]                        |
      | "module.a"     | foo.bar            | foo.baz               | module.a[*].foo.bar[*]           | module.a[*].foo.baz[*]            |
      | "module.a"     | foo.bar            | module.b[0].foo.baz   | module.a[*].foo.bar[*]           | module.a[*].module.b[0].foo.baz[*]|
      | ""             | foo.bar            | foo.bar["thing"]      | foo.bar                          | foo.bar["thing"]                  |
      | ""             | foo.bar["thing"]   | foo.bar               | foo.bar["thing"]                 | foo.bar                           |
      | ""             | module.foo         | module.bar            | module.foo[*]                    | module.bar[*]                     |
      | "module.bloop" | module.foo         | module.bar.module.baz | module.bloop[*].module.foo[*]    | module.bloop[*].module.bar.module.baz[*] |
      | ""             | module.foo[0]      | module.foo["a"]       | module.foo[0]                    | module.foo["a"]                   |
      | ""             | module.foo         | foo.bar               | ""                               | ""                                | # Cannot unify module with resource
      | ""             | module.foo[0]      | foo.bar[0]            | ""                               | ""                                | # Cannot unify module instance with resource instance

  Scenario Outline: Getting ConfigMoveable from a MoveEndpoint
    Given a MoveEndpoint parsed from HCL traversal "<TraversalString>"
    And it is considered within the context of module "<ContextModulePath>"
    When ConfigMoveable() is called on the MoveEndpoint with the context module
    Then the resulting ConfigMoveable address should be "<ExpectedConfigMoveableString>"
    And its type should be <ExpectedConfigMoveableType>

    Examples:
      | TraversalString           | ContextModulePath | ExpectedConfigMoveableString    | ExpectedConfigMoveableType |
      | foo.bar                   | ""                | foo.bar                         | ConfigResource             |
      | foo.bar[0]                | ""                | foo.bar                         | ConfigResource             | # Index is dropped for ConfigResource
      | module.foo.bar.baz        | ""                | module.foo.bar.baz              | ConfigResource             |
      | foo.bar                   | "module.boop"     | module.boop.foo.bar             | ConfigResource             |
      | module.bloop.foo.bar      | "module.bleep"    | module.bleep.module.bloop.foo.bar | ConfigResource             |
      | module.foo                | ""                | module.foo                      | Module                     |
      | module.foo[0]             | ""                | module.foo                      | Module                     | # Index is dropped for Module
      | module.bloop              | "module.bleep"    | module.bleep.module.bloop       | Module                     |

  # Note:
  # - MoveEndpoint.relSubject stores the parsed address relative to the `moved` block's declaration.
  # - UnifyMoveEndpoints resolves these relative addresses to absolute MoveEndpointInModule based on the declaration module.
  # - The [*] in ExpectedUnified...String indicates that any instance key becomes a wildcard for resource moves,
  #   or the module call itself for module moves, when unifying endpoints that don't specify instance keys.
  # - ConfigMoveable converts an endpoint to its configuration counterpart (e.g., a resource instance endpoint becomes a resource config address).
  # - cty is indirectly involved via InstanceKey in resource/module instance addresses.
  # - Step definitions will need to parse strings into HCL traversals, Module paths, and then into MoveEndpoint or specific address types.
  # - EffectiveAddrString for ParseMoveEndpoint reflects how the relSubject would be stringified.
  # - ExpectedConfigMoveableType refers to the Go type of the result (e.g., addrs.ConfigResource, addrs.Module).
