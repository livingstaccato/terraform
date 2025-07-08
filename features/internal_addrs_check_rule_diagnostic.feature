# Source Go File: internal/addrs/check_rule_diagnostic.go
# Source Go Test: internal/addrs/check_rule_diagnostic_test.go

Feature: Check Rule Diagnostic Handling
  This feature describes how diagnostic messages related to Terraform check rules
  are structured and identified, specifically using the CheckRuleDiagnosticExtra
  type to wrap additional context.

  Background:
    Given the Terraform diagnostic system

  Scenario: Wrapping and Unwrapping Diagnostic Extra Info with CheckRuleDiagnosticExtra
    Given an original hcl.Diagnostic with severity ERROR, summary "original error", detail "this is an error", and extra info "original extra"
    When this diagnostic's severity is overridden to WARNING using tfdiags.OverrideAll
    And a CheckRuleDiagnosticExtra wrapper is supplied during the override
    Then the overridden diagnostic's ExtraInfo should be a CheckRuleDiagnosticExtra instance
    And this CheckRuleDiagnosticExtra instance should wrap the "original extra" info
    When tfdiags.ExtraInfo[string] is used to unwrap the extra info from the overridden diagnostic
    Then the result should be the "original extra" string

  Scenario: Determining if a diagnostic should be consolidated based on CheckRuleDiagnosticExtra
    Given a diagnostic D1 with severity ERROR, summary "original error"
    And D1 has ExtraInfo of type CheckRuleDiagnosticExtra
    And the CheckRuleDiagnosticExtra for D1 refers to a CheckRule for an AbsOutputValue with type OutputPrecondition
    And a diagnostic D2 with severity ERROR, summary "original error"
    And D2 has ExtraInfo of type CheckRuleDiagnosticExtra
    And the CheckRuleDiagnosticExtra for D2 refers to a CheckRule for an AbsCheck with type CheckAssertion
    When tfdiags.DoNotConsolidateDiagnostic is called for D1
    Then the result should be false (meaning D1 can be consolidated)
    When tfdiags.DoNotConsolidateDiagnostic is called for D2
    Then the result should be true (meaning D2 should not be consolidated)

  Scenario: Identifying if a diagnostic originates from a CheckRule
    Given a diagnostic D_NoExtra with severity ERROR and summary "error" (no ExtraInfo)
    And a diagnostic D_WithCheckExtra with severity ERROR, summary "error", and ExtraInfo of type CheckRuleDiagnosticExtra
    When DiagnosticOriginatesFromCheckRule is called for D_NoExtra
    Then the result should indicate it does not originate from a CheckRule (ok is false)
    When DiagnosticOriginatesFromCheckRule is called for D_WithCheckExtra
    Then the result should indicate it originates from a CheckRule (ok is true)
    And the returned CheckRuleDiagnosticExtra should be the one from D_WithCheckExtra

  # Note: The cty aspects here are indirect. While CheckRuleDiagnosticExtra itself doesn't
  # heavily use cty, the CheckRule it might contain can refer to addresses (AbsCheck, AbsOutputValue)
  # which are part of the broader addressing system that does use cty for keys.
  # The BDD focuses on the behavior of the diagnostic wrapper and its interaction with the tfdiags package.
  # Step definitions will need to construct hcl.Diagnostic and CheckRuleDiagnosticExtra instances.
  # The CheckRule construction (NewCheckRule, AbsOutputValue, AbsCheck, etc.) will involve types from internal/addrs.
