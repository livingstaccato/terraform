# Metadata:
# Covers: internal/addrs/move_endpoint_module_test.go
# TestFunctions:
# - TestModuleInstanceMoveDestination
# - TestAbsResourceInstanceMoveDestination
# - TestAbsResourceMoveDestination
# - TestMoveEndpointChainAndNested
# - TestSelectsModule
# - TestSelectsResource
# - TestIsModuleMoveReIndex

Feature: Move Operation Endpoint Logic for Modules and Resources
  This feature describes how Terraform determines the new address of a module instance,
  resource instance, or resource when a 'moved' block is processed. It also covers
  relationships between move endpoints, such as chaining and nesting, and how
  endpoints select specific addresses.

  Background:
    Given a Terraform addressing system

  Scenario Outline: Module Instance Move Destination
    Given a 'moved' block declared in module "<DeclModule>"
    And the 'from' address in the moved block is "<FromAddr>"
    And the 'to' address in the moved block is "<ToAddr>"
    And a module instance with current address "<ReceiverAddr>"
    When the move destination for the module instance is calculated
    Then the move operation should <MatchOrNot> for the receiver
    And if matched, the new module instance address should be "<NewAddr>"

    Examples:
      # Basic move
      | DeclModule | FromAddr   | ToAddr     | ReceiverAddr | MatchOrNot | NewAddr    |
      |            | module.foo | module.bar | module.foo   | match      | module.bar |
      |            | module.foo | module.bar | module.foo[1]| match      | module.bar[1]|
      # Nested move
      |            | module.foo | module.bar.module.foo | module.foo   | match      | module.bar.module.foo |
      # Re-indexing
      |            | module.foo[1] | module.foo[2] | module.foo[1] | match      | module.foo[2] |
      |            | module.foo[1] | module.foo    | module.foo[1] | match      | module.foo    |
      # Move affecting child module
      |            | module.foo | module.foo[1] | module.foo.module.bar | match      | module.foo[1].module.bar |
      # Move within a declared module context
      | foo        | module.bar | module.baz    | module.foo.module.bar | match      | module.foo.module.baz |
      # Non-matching cases
      |            | module.foo[1] | module.foo[2] | module.foo    | not match  |            | # Receiver has non-matching key
      |            | module.foo[1] | module.foo[2] | module.foo[2] | not match  |            | # Receiver is already 'to'
      |            | module.foo    | module.bar    |               | not match  |            | # Root module cannot be moved
      | foo        | module.bar    | module.baz    | module.boz    | not match  |            | # Receiver outside decl module

  Scenario Outline: Absolute Resource Instance Move Destination
    Given a 'moved' block declared in module "<DeclModule>"
    And the 'from' address in the moved block is "<FromAddr>"
    And the 'to' address in the moved block is "<ToAddr>"
    And an absolute resource instance with current address "<ReceiverAddr>"
    When the move destination for the resource instance is calculated
    Then the move operation should <MatchOrNot> for the receiver
    And if matched, the new resource instance address should be "<NewAddr>"

    Examples:
      # Basic resource move
      | DeclModule | FromAddr         | ToAddr           | ReceiverAddr     | MatchOrNot | NewAddr        |
      |            | test_object.beep | test_object.boop | test_object.beep | match      | test_object.boop |
      # Resource re-indexing
      |            | test_object.beep | test_object.beep[2] | test_object.beep | match      | test_object.beep[2] |
      # Resource moving into a module
      |            | test_object.beep | module.foo.test_object.beep | test_object.beep | match      | module.foo.test_object.beep |
      # Resource moving out of a module
      |            | module.foo.test_object.beep | test_object.beep | module.foo.test_object.beep | match      | test_object.beep |
      # Resource move within a declared module context
      | foo        | test_object.beep | test_object.boop | module.foo[0].test_object.beep | match      | module.foo[0].test_object.boop |
      # Moving a module implicitly moves its resources
      |            | module.foo       | module.bar       | module.foo.test_object.beep    | match      | module.bar.test_object.beep |
      |            | module.foo[1]    | module.foo[2]    | module.foo[1].test_object.beep | match      | module.foo[2].test_object.beep |
      # Non-matching cases
      |            | test_object.beep | test_object.boop | test_object.boop | not match  |            | # Receiver is already 'to'
      |            | test_object.beep[1] | test_object.beep[2] | test_object.beep[5] | not match  |            | # Non-matching instance key
      | foo        | test_object.beep | test_object.boop | test_object.beep   | not match  |            | # Receiver not in decl module instance

  Scenario Outline: Absolute Resource Move Destination (for whole resource, not instance)
    Given a 'moved' block declared in module "<DeclModule>"
    And the 'from' address in the moved block is "<FromAddr>"
    And the 'to' address in the moved block is "<ToAddr>"
    And an absolute resource (not a specific instance) with current address "<ReceiverAddr>"
    When the move destination for the resource is calculated
    Then the move operation should <MatchOrNot> for the receiver
    And if matched, the new resource address should be "<NewAddr>"

    Examples:
      # Basic resource move
      | DeclModule | FromAddr         | ToAddr           | ReceiverAddr     | MatchOrNot | NewAddr        |
      |            | test_object.beep | test_object.boop | test_object.beep | match      | test_object.boop |
      # Resource moving into a module
      |            | test_object.beep | module.foo.test_object.beep | test_object.beep | match      | module.foo.test_object.beep |
      # Moving a module implicitly moves its resources
      |            | module.foo       | module.bar       | module.foo.test_object.beep | match      | module.bar.test_object.beep |
      # Non-matching
      |            | test_object.beep | test_object.boop | test_object.boop | not match  |            | # Receiver is already 'to'
      | foo        | test_object.beep | test_object.boop | test_object.beep | not match  |            | # Receiver not in decl module instance

  Scenario Outline: Move Endpoint Relationships - Chaining and Nesting
    Given a move endpoint "EP1" for subject "<Subject1>" in module "<Module1Path>"
    And another move endpoint "EP2" for subject "<Subject2>" in module "<Module2Path>"
    When I check if "EP1" can chain from "EP2"
    Then the result should be <CanChain>
    When I check if "EP1" is nested within "EP2"
    Then the result should be <IsNested>

    Examples:
      # Identical module call endpoints
      | Subject1                                        | Module1Path | Subject2                                        | Module2Path | CanChain | IsNested |
      | module.foo[2].call.bar                          |             | module.foo[2].call.bar                          |             | true     | false    |
      # Module instance and module call
      | module.foo[2]                                   |             | module.foo[2].call.bar                          |             | false    | false    |
      | module.foo[2].call.bar                          |             | module.foo[2]                                   |             | false    | true     |
      # Nested module instance
      | module.foo[2].module.bar[2]                     |             | root.call.foo                                   |             | false    | true     |
      # Resource nested within module call
      | module.foo[2].module.bar.resource_type.baz      |             | module.foo[2].call.bar                          |             | false    | true     |
      # Identical resource endpoints
      | module.foo[2].resource_type.baz                 |             | module.foo[2].resource_type.baz                 |             | true     | false    |
      # Resource instance nested in resource
      | module.foo[2].resource_type.baz[2]              |             | module.foo[2].resource_type.baz                 |             | false    | true     |
      # Relative paths with module context
      | resource_type.baz                               | foo         | module.foo[2].resource_type.baz                 |             | true     | false    |
      | module.foo[2].resource_type.baz                 |             | resource_type.baz                               | foo         | true     | false    |
      | resource_type.baz                               | foo         | module.foo[2].resource_type.baz                 |             | false    | true     | # Endpoint is relative, other is absolute path that contains it
      | module.foo[2].module.call.bing                  |             | module.baz.call.bing                            | foo         | true     | false    | # Chaining complex relative paths
      | module.bing.call.bang                           | foo.baz     | module.foo.module.baz.call.bing                 |             | false    | true     | # Nesting complex relative paths

  Scenario Outline: Move Endpoint Module Selection
    Given a move endpoint for subject "<Subject>" in module "<ModulePath>"
    And a target module instance address "<TargetModuleAddr>"
    When I check if the endpoint selects the target module instance
    Then the result should be <Selects>

    Examples:
      | Subject                                     | ModulePath | TargetModuleAddr                      | Selects |
      | module.foo[2].call.bar                      |            | module.foo[2].module.bar[1]           | true    |
      | module.bar[2].call.baz                      | foo        | module.foo[2].module.bar[2].module.baz| true    |
      | module.bar[2].call.baz                      | foo        | module.foo[2].module.bar[1].module.baz| false   | # Different instance key for bar
      | module.bar.call.baz                         |            | module.bar[1].module.baz              | false   | # Endpoint subject implies no specific instance for bar
      | module.bar.resource_type.name["key"]        | foo        | module.foo[1].module.bar              | true    |
      | module.bar.module.baz["key"]                |            | module.bar.module.baz["key"]          | true    |
      | module.bar.module.baz["key"].resource_type.name |            | module.bar.module.baz["key"]          | true    |
      | module.bar.resource_type.name["key"]        | nope       | module.foo[1].module.bar              | false   | # Endpoint module context mismatch

  Scenario Outline: Move Endpoint Resource Selection
    Given a move endpoint for subject "<Subject>" in module "<ModulePath>"
    And a target absolute resource address "<TargetResourceAddr>"
    When I check if the endpoint selects the target resource
    Then the result should be <Selects>

    Examples:
      | Subject                                          | ModulePath | TargetResourceAddr                             | Selects |
      | resource_type.matching_name.foo                  |            | resource_type.matching_name.foo                | true    | # Exact match
      | resource_type.unmatching_name.foo                |            | resource_type.matching_name.foo                | false   | # Different name
      | resource_type.matching_name.foo[0]               |            | resource_type.matching_name.foo                | true    | # Endpoint is instance, target is whole resource
      | resource_type.matching_name.foo                  | child      | module.child["matching"].resource_type.matching_name.foo | true    | # In decl module instance
      | resource_type.matching_name.foo[2]               | child      | module.child["matching"].resource_type.matching_name.foo | true    |
      | resource_type.matching_name.foo                  | child      | module.child["unmatching"].resource_type.matching_name.foo | false   | # Decl module instance key mismatch
      | module.foo[2].call.bar                           |            | resource_type.matching_name.foo                | false   | # Module call cannot select resource

  Scenario Outline: Checking if a Module Move is a Re-Index Operation
    Given a 'from' move endpoint subject "<FromSubject>" in module "<FromModulePath>"
    And a 'to' move endpoint subject "<ToSubject>" in module "<ToModulePath>"
    When I check if moving from this 'from' endpoint to this 'to' endpoint is a module re-index operation
    Then the result should be <IsReindex>

    Examples:
      # Simple re-index
      | FromSubject                | FromModulePath | ToSubject                  | ToModulePath | IsReindex |
      | module.bar                 |                | module.bar                 |              | true      |
      | module.bar                 |                | module.bar[0]              |              | true      |
      | root.call.bar              |                | module.bar[0]              |              | true      |
      | module.bar["a"]            |                | root.call.bar              |              | true      |
      # Not a re-index (different module names)
      | module.foo                 |                | module.bar                 |              | false     |
      | root.call.bar              |                | module.foo[0]              |              | false     |
      # Nested re-index
      | module.bar.module.baz      |                | module.bar.module.baz[0]   |              | true      |
      | module.bar[0].module.baz   |                | module.bar.module.baz[0]   |              | true      |
      | module.bar[0].call.baz     |                | module.bar.module.baz[0]   |              | true      | # 'from' is call, 'to' is instance of that call
      # Not a re-index (path mismatch)
      | module.bar.module.baz      |                | module.baz.module.baz      |              | false     |
      | root.call.baz              |                | module.bar.module.baz[0]   |              | false     | # 'from' call is in root, 'to' is nested

```

Notes on this extensive Gherkin:

*   I've used `<DeclModule>`, `<FromAddr>`, `<ToAddr>`, etc. as placeholders. The step definitions will need to parse these into the appropriate `MoveEndpoint` and other address structures. Empty `<DeclModule>` implies the root module.
*   For subjects like `module.foo[2].call.bar`, this implies an `AbsModuleCall` subject. `module.foo[2]` implies `ModuleInstance`. `resource_type.name` implies `AbsResource`. `resource_type.name[0]` implies `AbsResourceInstance`. The step definitions will need robust parsing or clarification if ambiguity arises.
*   The examples for each scenario are drawn from the Go test cases, trying to pick representative samples that illustrate the rule being tested. It's not a 1:1 mapping of every single test struct due to the sheer volume.
*   "Root" is used in subjects like `root.call.foo` to clearly denote a call made from the root module, which translates to an `AbsModuleCall` with `Module: RootModuleInstance`.
*   This is a complex area, and the Gherkin aims to make the high-level rules understandable. The specifics of parsing and constructing the `MoveEndpoint` objects are abstracted into the "Given" steps.

This is a large file. I'll proceed to the next one: `internal/addrs/move_endpoint_test.go`.
