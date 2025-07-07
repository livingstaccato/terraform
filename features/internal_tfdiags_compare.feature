# Source Go File: internal/tfdiags/compare.go
# Source Go Test: internal/tfdiags/compare_test.go

Feature: Comparing Terraform Diagnostics
  This feature describes how Terraform diagnostics are compared for equality,
  particularly focusing on how differences in cty.Path for attribute-based
  diagnostics affect the comparison.

  Background:
    Given a base diagnostic with severity "ERROR", summary "error", detail "this is an error"
    And the base diagnostic subject is file "foobar.tf" from line 0 col 0 to line 1 col 1

  Scenario: Identical diagnostics match
    Given diagnostic1 is an hclDiagnostic based on the base diagnostic
    And diagnostic2 is an hclDiagnostic based on the base diagnostic
    When diagnostic1 and diagnostic2 are compared using DiagnosticComparer
    Then no difference should be detected

  Scenario Outline: Diagnostics with differing attribute paths do not match
    Given diagnostic1 is an AttributeValue diagnostic with severity "ERROR", summary "summary here", detail "detail here"
    And diagnostic1 has a cty.Path with a GetAttrStep named "<PathName1>"
    And diagnostic2 is an AttributeValue diagnostic with severity "ERROR", summary "summary here", detail "detail here"
    And diagnostic2 has a cty.Path with a GetAttrStep named "<PathName2>"
    When diagnostic1 and diagnostic2 are compared using DiagnosticComparer
    Then a difference should be detected

    Examples:
      | PathName1 | PathName2 |
      | "foobar1" | "foobar2" |

  Scenario: Diagnostics with one having an attribute path and other not, do not match
    Given diagnostic1 is an AttributeValue diagnostic with severity "ERROR", summary "summary here", detail "detail here"
    And diagnostic1 has a cty.Path with a GetAttrStep named "foobar1"
    And diagnostic2 is an AttributeValue diagnostic with severity "ERROR", summary "summary here", detail "detail here"
    And diagnostic2 has an empty cty.Path
    When diagnostic1 and diagnostic2 are compared using DiagnosticComparer
    Then a difference should be detected

  Scenario: Diagnostics with different cty.Path structures (e.g. one with index)
    Given diagnostic1 is an AttributeValue diagnostic with severity "ERROR", summary "summary", detail "detail"
    And diagnostic1 has a cty.Path with a GetAttrStep "attr"
    And diagnostic2 is an AttributeValue diagnostic with severity "ERROR", summary "summary", detail "detail"
    And diagnostic2 has a cty.Path with a GetAttrStep "attr" followed by an IndexStep with number key 0
    When diagnostic1 and diagnostic2 are compared using DiagnosticComparer
    Then a difference should be detected

  Scenario: Diagnostics with identical non-empty cty.Paths match (if other fields match)
    Given diagnostic1 is an AttributeValue diagnostic with severity "ERROR", summary "summary", detail "detail"
    And diagnostic1 has a cty.Path with a GetAttrStep "data" then GetAttrStep "source"
    And diagnostic2 is an AttributeValue diagnostic with severity "ERROR", summary "summary", detail "detail"
    And diagnostic2 has a cty.Path with a GetAttrStep "data" then GetAttrStep "source"
    When diagnostic1 and diagnostic2 are compared using DiagnosticComparer
    Then no difference should be detected

  Scenario: Diagnostics with different concrete types do not match
    Given diagnostic1 is an hclDiagnostic based on the base diagnostic
    And diagnostic2 is an rpcFriendlyDiagnostic based on the base diagnostic (same content, different type)
    When diagnostic1 and diagnostic2 are compared using DiagnosticComparer
    Then a difference should be detected

  Scenario: Diagnostics with different severities do not match
    Given diagnostic1 is an hclDiagnostic based on the base diagnostic with severity "ERROR"
    And diagnostic2 is an hclDiagnostic based on the base diagnostic but with severity "WARNING"
    When diagnostic1 and diagnostic2 are compared using DiagnosticComparer
    Then a difference should be detected

  Scenario: Diagnostics with different summaries do not match
    Given diagnostic1 is an hclDiagnostic based on the base diagnostic with summary "error"
    And diagnostic2 is an hclDiagnostic based on the base diagnostic but with summary "different error"
    When diagnostic1 and diagnostic2 are compared using DiagnosticComparer
    Then a difference should be detected

  Scenario: Diagnostics with different details do not match
    Given diagnostic1 is an hclDiagnostic based on the base diagnostic with detail "this is an error"
    And diagnostic2 is an hclDiagnostic based on the base diagnostic but with detail "this is a different error"
    When diagnostic1 and diagnostic2 are compared using DiagnosticComparer
    Then a difference should be detected
