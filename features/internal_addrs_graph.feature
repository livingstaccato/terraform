# Source Go File: internal/addrs/graph.go
# Source Go Test: internal/addrs/graph_test.go

Feature: Addressable Item Dependency Graph
  This feature describes the functionality of a directed graph used to manage
  dependencies between addressable Terraform items (like LocalValue, Resource, etc.).
  It covers adding dependencies, querying direct and transitive dependencies/dependents,
  and string representation for comparison.

  Background:
    Given an empty directed graph for addressable items

  Scenario: Building and representing a dependency graph
    Given the following dependencies are added to the graph:
      | Dependent   | Dependency  |
      | local_value.d | local_value.c |
      | local_value.d | local_value.b |
      | local_value.c | local_value.b |
      | local_value.b | local_value.a |
      # Items are of type LocalValue with names "a", "b", "c", "d"
    When the graph's StringForComparison method is called
    Then the result should be a string representation:
    """
    local.a
    local.b
      local.a
    local.c
      local.b
    local.d
      local.b
      local.c
    """

  Scenario Outline: Querying direct dependencies
    Given a graph with dependencies: d->c, d->b, c->b, b->a (all LocalValue items)
    When DirectDependenciesOf is called for item "<ItemName>"
    Then the result should be a set of items: <ExpectedDirectDependencies>

    Examples:
      | ItemName      | ExpectedDirectDependencies |
      | local_value.a | []                         |
      | local_value.b | [local_value.a]            |
      | local_value.c | [local_value.b]            |
      | local_value.d | [local_value.b, local_value.c] |

  Scenario Outline: Querying direct dependents
    Given a graph with dependencies: d->c, d->b, c->b, b->a (all LocalValue items)
    When DirectDependentsOf is called for item "<ItemName>"
    Then the result should be a set of items: <ExpectedDirectDependents>

    Examples:
      | ItemName      | ExpectedDirectDependents     |
      | local_value.a | [local_value.b]              |
      | local_value.b | [local_value.c, local_value.d] |
      | local_value.c | [local_value.d]              |
      | local_value.d | []                           |

  Scenario Outline: Querying transitive dependencies
    Given a graph with dependencies: d->c, d->b, c->b, b->a (all LocalValue items)
    When TransitiveDependenciesOf is called for item "<ItemName>"
    Then the result should be a set of items: <ExpectedTransitiveDependencies>

    Examples:
      | ItemName      | ExpectedTransitiveDependencies             |
      | local_value.a | []                                         |
      | local_value.b | [local_value.a]                            |
      | local_value.c | [local_value.a, local_value.b]             | # b depends on a
      | local_value.d | [local_value.a, local_value.b, local_value.c] | # c depends on b, b depends on a

  Scenario Outline: Querying transitive dependents
    Given a graph with dependencies: d->c, d->b, c->b, b->a (all LocalValue items)
    When TransitiveDependentsOf is called for item "<ItemName>"
    Then the result should be a set of items: <ExpectedTransitiveDependents>

    Examples:
      | ItemName      | ExpectedTransitiveDependents               |
      | local_value.a | [local_value.b, local_value.c, local_value.d] | # b depends on a, c depends on b, d depends on c & b
      | local_value.b | [local_value.c, local_value.d]             | # c depends on b, d depends on c & b
      | local_value.c | [local_value.d]                            |
      | local_value.d | []                                         |

  # Note: The graph implementation is generic (NewDirectedGraph[T Adr]).
  # The BDD uses LocalValue as a concrete type for T, matching the test.
  # Step definitions will need to:
  # - Create addrs.LocalValue instances from strings like "local_value.a".
  # - Populate the graph.
  # - Convert the resulting sets of addresses from graph queries back to lists of strings for comparison.
  # - The cty aspect is minimal here, mostly about how addressable items (which can have cty-based keys)
  #   are used as nodes in a graph, but the graph logic itself is generic.
  # - The StringForComparison output needs careful matching, including indentation.
