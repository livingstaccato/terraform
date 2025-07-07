# Source Go File: internal/tfdiags/hcl.go
# Source Go Test: internal/tfdiags/hcl_test.go

Feature: Conversion between tfdiags and HCL Diagnostics
  Describes how Terraform's internal diagnostic format (tfdiags) is converted
  to HCL's diagnostic format, particularly concerning expressions that involve cty.Value.

  Scenario: Converting tfdiags containing an HCL diagnostic with an expression to HCL diagnostics
    Given a tfdiag "diag_hcl" which is an hcl.Diagnostic with:
      | field         | value                                            |
      | Severity      | hcl.DiagWarning                                  |
      | Summary       | "A diagnostic from HCL"                          |
      | Detail        | "...that has a detail and source information"    |
      | Subject       | file "test.tf", range [1,2,1]-[1,3,2]            | # Line, Col, Byte
      | Context       | file "test.tf", range [1,1,0]-[1,4,3]            |
      | EvalContext   | a valid hcl.EvalContext                          |
      | Expression    | a fakeHCLExpression that returns cty.DynamicVal  |
    And a tfdiags.Diagnostics list containing "diag_hcl"
    When these tfdiags.Diagnostics are converted to hcl.Diagnostics
    Then the resulting hcl.Diagnostics list should have 1 item
    And the first item should be an hcl.Diagnostic with:
      | field         | value                                            |
      | Severity      | hcl.DiagWarning                                  |
      | Summary       | "A diagnostic from HCL"                          |
      | Detail        | "...that has a detail and source information"    |
      | Subject       | file "test.tf", range [1,2,1]-[1,3,2]            |
      | Context       | file "test.tf", range [1,1,0]-[1,4,3]            |
      | EvalContext   | (original EvalContext should be preserved)       |
      | Expression    | (original Expression should be preserved)        |

  Scenario: Converting tfdiags AttributeValue diagnostic to HCL
    Given an AttributeValue diagnostic "attr_diag" with severity "ERROR", summary "Attribute Error", detail "Error on attribute"
    And "attr_diag" refers to cty.Path with GetAttrStep "my_resource" then GetAttrStep "my_attribute"
    And "attr_diag" has been elaborated to have Subject: file "config.tf", range [5,10,100]-[5,20,110]
    And a tfdiags.Diagnostics list containing "attr_diag"
    When these tfdiags.Diagnostics are converted to hcl.Diagnostics
    Then the resulting hcl.Diagnostics list should have 1 item
    And the first item should be an hcl.Diagnostic with:
      | field         | value                                         |
      | Severity      | hcl.DiagError                                 |
      | Summary       | "Attribute Error"                             |
      | Detail        | "Error on attribute"                          |
      | Subject       | file "config.tf", range [5,10,100]-[5,20,110] |
      # EvalContext and Expression would be nil as AttributeValue doesn't inherently carry them in a way that maps to hcl.Diagnostic's fields
    And its EvalContext should be nil
    And its Expression should be nil

  Scenario: Round trip of SourceRange to HCL Range and back
    Given a tfdiags.SourceRange for "main.tf" from line 1, col 5, byte 4 to line 2, col 10, byte 20
    When this SourceRange is converted to an hcl.Range
    Then the hcl.Range should have filename "main.tf"
    And its start position should be line 1, col 5, byte 4
    And its end position should be line 2, col 10, byte 20
    When this hcl.Range is converted back to a tfdiags.SourceRange using SourceRangeFromHCL
    Then the resulting tfdiags.SourceRange should have filename "main.tf"
    And its start position should be line 1, col 5, byte 4
    And its end position should be line 2, col 10, byte 20

  Scenario: Converting tfdiags.Diagnostics list with various types to hcl.Diagnostics
    Given a tfdiags.Diagnostics list containing:
      1. A Sourceless tfdiag with Severity ERROR, Summary "SL Error", Detail "Detail SL"
      2. An Errorf tfdiag (from fmt.Errorf) with Summary "Errorf Error"
      3. A SimpleWarning tfdiag with Summary "Simple Warn"
    When these tfdiags.Diagnostics are converted to hcl.Diagnostics
    Then the resulting hcl.Diagnostics list should have 3 items
    And the first item should have Severity hcl.DiagError and Summary "SL Error" and Detail "Detail SL"
    And the second item should have Severity hcl.DiagError and Summary "Errorf Error"
    And the third item should have Severity hcl.DiagWarning and Summary "Simple Warn"

# Note: The fakeHCLExpression in hcl_test.go returns cty.DynamicVal.
# While this is a cty.Value, the tests for hcl.go are more about the passthrough
# of the hcl.Expression interface itself during conversion, rather than deep
# inspection or manipulation of the cty.DynamicVal within this specific module.
# The BDDs reflect this focus on the conversion process.
