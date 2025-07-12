# Metadata:
# Covers: internal/addrs/check_rule_diagnostic_test.go
# TestFunctions:
# - TestCheckRuleDiagnosticExtra_WrapsExtra
# - TestCheckRuleDiagnosticExtra_Unwraps
# - TestCheckRuleDiagnosticExtra_DoNotConsolidate
# - TestDiagnosticOriginatesFromCheckRule_Passes

Feature: Check Rule Diagnostic Extras
  This feature describes how extra information associated with check rule diagnostics
  is handled, including wrapping, unwrapping, and its effect on diagnostic consolidation.

  Background:
    Given a diagnostic system

  Scenario: Wrapping Original Diagnostic Extra Information
    Given an original HCL diagnostic with severity "Error", summary "original error", detail "this is an error", and extra string "extra"
    When I override the diagnostic's severity to "Warning" using a "CheckRuleDiagnosticExtra" wrapper
    Then the overridden diagnostic's extra information should be a "CheckRuleDiagnosticExtra"
    And the wrapped original extra string should be "extra"

  Scenario: Unwrapping Diagnostic Extra Information
    Given an original HCL diagnostic with severity "Error", summary "original error", detail "this is an error", and extra string "extra"
    When I override the diagnostic's severity to "Warning" using a "CheckRuleDiagnosticExtra" wrapper
    And I attempt to unwrap the extra information as a string from the overridden diagnostic
    Then the unwrapped string should be "extra"

  Scenario: Consolidation Behavior of Diagnostics with CheckRuleDiagnosticExtra
    Given a diagnostic "Diag1" with severity "Error", summary "original error", and detail "this is an error"
    And "Diag1" has "CheckRuleDiagnosticExtra" with a check rule for an "AbsOutputValue" named "output" of type "OutputPrecondition"
    And a diagnostic "Diag2" with severity "Error", summary "original error", and detail "this is an error"
    And "Diag2" has "CheckRuleDiagnosticExtra" with a check rule for an "AbsCheck" named "check" of type "CheckAssertion"
    When I check if "Diag1" should be prevented from consolidation
    Then "Diag1" should be allowed to consolidate
    When I check if "Diag2" should be prevented from consolidation
    Then "Diag2" should NOT be allowed to consolidate

  Scenario: Identifying Diagnostics Originating from a Check Rule
    Given a diagnostic "D1" with severity "Error", summary "original error", and detail "this is an error" but no extra info
    And a diagnostic "D2" with severity "Error", summary "original error", detail "this is an error", and "CheckRuleDiagnosticExtra"
    When I check if "D1" originates from a check rule
    Then it should be identified as NOT originating from a check rule
    When I check if "D2" originates from a check rule
    Then it should be identified as originating from a check rule
    And the associated CheckRuleDiagnosticExtra should be retrievable
