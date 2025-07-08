# Source Go File: internal/configs/hcl2shim/values_equiv.go
# Source Go Test: internal/configs/hcl2shim/values_equiv_test.go

Feature: HCL2 Shim Value Equivalence for SDK
  This feature describes how cty.Value objects are compared for equivalence
  in a way that mimics the legacy SDK's diffing behavior. This is crucial
  for determining if a change in value constitutes a "real" change that
  the SDK would act upon.

  Background:
    Given the HCL2 shim environment for value equivalence

  Scenario Outline: Comparing two cty.Values for SDK equivalence
    Given cty.Value A is <ValueADescription>
    And cty.Value B is <ValueBDescription>
    When ValuesSDKEquivalent(A, B) is called
    Then the result should be <ExpectedEquivalence>
    # And symmetrically, ValuesSDKEquivalent(B, A) should also be <ExpectedEquivalence>

    Examples:
      # Basic string comparisons
      | ValueADescription        | ValueBDescription        | ExpectedEquivalence |
      | StringVal "hello"        | StringVal "hello"        | true                |
      | StringVal "hello"        | StringVal "world"        | false               |
      | StringVal "hello"        | StringVal ""             | false               |
      | NullVal(String)          | StringVal ""             | true                | # Null string is like empty string for SDK

      # Basic number comparisons
      | ValueADescription        | ValueBDescription        | ExpectedEquivalence |
      | NumberIntVal 1           | NumberIntVal 1           | true                |
      | NumberIntVal 1           | NumberIntVal 2           | false               |
      | NumberIntVal 1           | Zero (Number)            | false               |
      | NullVal(Number)          | Zero (Number)            | true                | # Null number is like zero for SDK
      | NumberVal(big Pi)        | Zero (Number)            | false               |
      | NumberFloatVal(pi64)     | Zero (Number)            | false               |
      | NumberFloatVal(pi64)     | NumberVal(big Pi)        | true                | # float64 precision equivalence

      # Basic boolean comparisons
      | ValueADescription        | ValueBDescription        | ExpectedEquivalence |
      | True (Bool)              | True (Bool)              | true                |
      | True (Bool)              | False (Bool)             | false               |
      | NullVal(Bool)            | False (Bool)             | true                | # Null bool is like false for SDK

      # Mixed primitive type comparisons (zero-value equivalence)
      | ValueADescription        | ValueBDescription        | ExpectedEquivalence |
      | StringVal "hello"        | False (Bool)             | false               |
      | StringVal ""             | False (Bool)             | true                |
      | NumberIntVal 0           | False (Bool)             | true                |
      | StringVal ""             | NumberIntVal 0           | true                |
      | NullVal(Bool)            | NullVal(Number)          | true                |
      | StringVal ""             | NullVal(Number)          | true                |

      # List comparisons
      | ValueADescription        | ValueBDescription        | ExpectedEquivalence |
      | ListValEmpty(String)     | ListValEmpty(String)     | true                |
      | ListValEmpty(String)     | NullVal(List(String))    | true                |
      | ListVal ["hello"] (Str)  | ListVal ["hello","hello"] (Str) | false          | # Different length
      | ListVal ["hello"] (Str)  | ListValEmpty(String)     | false               |
      | ListVal ["hello"] (Str)  | ListVal ["hello"] (Str)  | true                |
      | ListVal ["hello"] (Str)  | ListVal ["world"] (Str)  | false               |
      | ListVal [NullVal(Str)]   | ListVal [StringVal ""]   | true                | # Element-wise equivalence

      # Tuple comparisons (similar to lists)
      | ValueADescription        | ValueBDescription        | ExpectedEquivalence |
      | EmptyTupleVal            | EmptyTupleVal            | true                |
      | EmptyTupleVal            | NullVal(EmptyTuple)      | true                |
      | TupleVal ["h"] (Str)     | TupleVal ["h","h"] (Str) | false               |
      | TupleVal ["h"] (Str)     | TupleVal ["w"] (Str)     | false               |
      | TupleVal [NullVal(Str)]  | TupleVal [StringVal ""]  | true                |

      # Set comparisons
      | ValueADescription        | ValueBDescription        | ExpectedEquivalence |
      | SetValEmpty(String)      | SetValEmpty(String)      | true                |
      | SetValEmpty(String)      | NullVal(Set(String))     | true                |
      | SetVal ["h"] (Str)       | SetValEmpty(String)      | false               |
      | SetVal ["h"] (Str)       | SetVal ["h"] (Str)       | true                |
      | SetVal ["h"] (Str)       | SetVal ["w"] (Str)       | false               |
      | SetVal [NullVal(Str)]    | SetVal [StringVal ""]    | true                |
      | SetVal [NullVal(Str), StringVal ""] | SetVal [NullVal(Str)] | false        | # Different length due to distinct equivalent elements
      | SetVal [Obj{"a":"","b":""}, Obj{"a":Null,"b":""}] | SetVal [Obj{"a":"","b":""}, Obj{"a":"","b":Null}] | true | # Complex set elements equivalence

      # Map comparisons
      | ValueADescription        | ValueBDescription        | ExpectedEquivalence |
      | MapValEmpty(String)      | MapValEmpty(String)      | true                |
      | MapValEmpty(String)      | NullVal(Map(String))     | true                |
      | MapVal {"h":"h"} (Str)   | MapVal {"h":"h","v":"v"} (Str) | false          | # Different length
      | MapVal {"h":"h"} (Str)   | MapValEmpty(String)      | false               |
      | MapVal {"h":"h"} (Str)   | MapVal {"h":"h"} (Str)   | true                |
      | MapVal {"h":"h"} (Str)   | MapVal {"h":"w"} (Str)   | false               |
      | MapVal {"h":NullVal(Str)}| MapVal {"h":StringVal ""} | true                | # Value-wise equivalence

      # Object comparisons (similar to maps)
      | ValueADescription        | ValueBDescription        | ExpectedEquivalence |
      | EmptyObjectVal           | EmptyObjectVal           | true                |
      | EmptyObjectVal           | NullVal(EmptyObject)     | true                |
      | ObjectVal {"h":"h"}      | ObjectVal {"h":"w"}      | false               |
      | ObjectVal {"h":NullVal(Str)} | ObjectVal {"h":StringVal ""} | true          |

      # Unknown value comparisons
      | ValueADescription        | ValueBDescription        | ExpectedEquivalence |
      | UnknownVal(String)       | UnknownVal(String)       | true                | # Unknowns of same type are equivalent
      | StringVal "hello"        | UnknownVal(String)       | false               | # Known is not equivalent to unknown
      | StringVal ""             | UnknownVal(String)       | false               |
      | NullVal(String)          | UnknownVal(String)       | false               | # Null is not equivalent to unknown here (both must be known or unknown)

  # Helper step definitions will be needed to:
  # - Parse <ValueADescription> and <ValueBDescription> into actual cty.Value objects.
  #   This includes handling "StringVal", "NumberIntVal", "NullVal(String)", "ListVal [...]", "SetVal [...]", "MapVal {...}", "ObjectVal {...}", "UnknownVal(...)", "Zero (Number)", "NumberVal(big Pi)", "NumberFloatVal(pi64)".
  # - The "Obj{...}" syntax in set examples implies creating cty.ObjectVal with specified attributes.
  # - Ensure symmetrical testing is either handled by the test runner or explicitly added if necessary.
  # - The values "big Pi" and "pi64" refer to specific numeric constants defined in the Go test.
  # - Equivalence logic for sets is fuzzy and order-independent.
  # - Equivalence for numbers handles precision differences between int, float64, and big.Float.
  # - Null values are often treated as equivalent to zero-values of their type (empty string, 0, false, empty collection).
  # - Known and unknown values are generally not equivalent unless both are unknown.
