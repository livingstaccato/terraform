# Metadata:
# Covers: internal/addrs/graph_test.go
# TestFunctions:
# - TestGraph (covers all sub-tests like StringForComparison, direct dependencies, transitive dependencies, etc.)

Feature: Directed Graph of Local Values
  This feature describes the behavior of a directed graph used to manage dependencies
  between local values in Terraform configurations.

  Background:
    Given a new directed graph for local values
    And local value "a" named "a"
    And local value "b" named "b"
    And local value "c" named "c"
    And local value "d" named "d"
    And the following dependencies are added to the graph:
      | From | To |
      | d    | c  |
      | d    | b  |
      | c    | b  |
      | b    | a  |

  Scenario: Graph String Representation for Comparison
    When I get the string representation of the graph for comparison
    Then the string representation should be:
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

  Scenario Outline: Direct Dependencies of a Local Value
    When I query the direct dependencies of local value "<LocalValue>"
    Then the number of direct dependencies should be <Count>
    And the direct dependencies should <IncludeOrNot> local values <Dependencies>

    Examples:
      | LocalValue | Count | IncludeOrNot | Dependencies |
      | a          | 0     | not include  | ""           |
      | b          | 1     | include      | "a"          |
      | d          | 2     | include      | "b, c"       |

  Scenario Outline: Direct Dependents of a Local Value
    When I query the direct dependents of local value "<LocalValue>"
    Then the number of direct dependents should be <Count>
    And the direct dependents should <IncludeOrNot> local values <Dependents>

    Examples:
      | LocalValue | Count | IncludeOrNot | Dependents   |
      | a          | 1     | include      | "b"          |
      | b          | 2     | include      | "c, d"       |
      | d          | 0     | not include  | ""           |

  Scenario Outline: Transitive Dependencies of a Local Value
    When I query the transitive dependencies of local value "<LocalValue>"
    Then the number of transitive dependencies should be <Count>
    And the transitive dependencies should <IncludeOrNot> local values <Dependencies>

    Examples:
      | LocalValue | Count | IncludeOrNot | Dependencies |
      | a          | 0     | not include  | ""           |
      | b          | 1     | include      | "a"          |
      | d          | 3     | include      | "a, b, c"    |

  Scenario Outline: Transitive Dependents of a Local Value
    When I query the transitive dependents of local value "<LocalValue>"
    Then the number of transitive dependents should be <Count>
    And the transitive dependents should <IncludeOrNot> local values <Dependents>

    Examples:
      | LocalValue | Count | IncludeOrNot | Dependents   |
      | a          | 3     | include      | "b, c, d"    |
      | b          | 2     | include      | "c, d"       |
      | d          | 0     | not include  | ""           |
