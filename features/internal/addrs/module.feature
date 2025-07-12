# Metadata:
# Covers: internal/addrs/module_test.go
# TestFunctions:
# - TestModuleEqual_true
# - TestModuleEqual_false
# - TestModuleString
# Note: Benchmark tests (BenchmarkModuleStringShort, BenchmarkModuleStringLong) are not typically covered by BDD.

Feature: Module Addressing and Equality
  This feature describes how module paths (configurations) are addressed,
  how their string representations are generated, and how they are compared for equality.
  Module addresses identify a specific module configuration within a Terraform project hierarchy.

  Scenario Outline: Module Self-Equality
    Given a module defined by the path segments <PathSegments>
    When I compare this module with itself
    Then they should be equal

    Examples:
      | PathSegments      | Description         |
      | []                | Root module         |
      | ["a"]             | Single-level module |
      | ["a", "b"]        | Two-level module    |
      | ["a", "b", "c"]   | Three-level module  |

  Scenario Outline: Module Comparison
    Given a module "M1" defined by path segments <LeftPathSegments>
    And a module "M2" defined by path segments <RightPathSegments>
    When I compare module "M1" with module "M2"
    Then they should <EqualityResult>

    Examples:
      | LeftPathSegments | RightPathSegments | EqualityResult | Description                  |
      | []               | ["a"]             | NOT be equal   | Root vs. child               |
      | ["a"]            | ["b"]             | NOT be equal   | Different child modules      |
      | ["a"]            | ["a", "a"]        | NOT be equal   | Parent vs. child             |
      | ["a", "b"]       | ["a", "B"]        | NOT be equal   | Case-sensitive difference    |

  Scenario Outline: Module String Representation
    Given a module defined by the path segments <PathSegments>
    When I generate its string representation
    Then the resulting string should be "<ExpectedString>"

    Examples:
      | PathSegments                 | ExpectedString                              | Description              |
      | []                           | ""                                          | Root module              |
      | ["alpha"]                    | module.alpha                                | Single-level module      |
      | ["alpha", "beta"]            | module.alpha.module.beta                    | Two-level module         |
      | ["alpha", "beta", "charlie"] | module.alpha.module.beta.module.charlie     | Three-level module       |

```

Notes on this Gherkin:

*   `<PathSegments>` is used to define the module structure. An empty list `[]` represents the `RootModule`. The step definition would convert this list of strings into a `addrs.Module`.
*   The `EqualityResult` makes the comparison scenarios more readable.
*   Benchmarks are noted as not covered.
*   The scenarios cover the core logic tested: self-equality, comparison with different modules, and string formatting.

Next, I'll look at `internal/addrs/move_endpoint_module_test.go`.
