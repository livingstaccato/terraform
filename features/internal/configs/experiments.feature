# Metadata:
# Covers: internal/configs/experiments_test.go
# TestFunctions:
# - TestExperimentsConfig

Feature: Configuration of Experimental Language Features
  This feature describes how Terraform configurations can declare the use of
  experimental language features via the 'terraform.experiments' block,
  and how the system validates and responds to these declarations.

  Background:
    Given a Terraform configuration parser
    And a set of known experiments: "current_feature" (active), "old_feature" (concluded with message "Use new_feature instead.")

  Scenario: Declaring an Active Experimental Feature
    Given language experiments are allowed by the parser
    And a configuration file containing:
      """
      terraform {
        experiments = [current_feature]
      }
      """
    When the configuration is loaded
    Then a warning diagnostic should be produced
    And the diagnostic summary should be 'Experimental feature "current_feature" is active'
    And the diagnostic detail should explain the risks of using experimental features
    And the loaded module should have "current_feature" in its set of active experiments

  Scenario: Declaring a Concluded Experimental Feature
    Given language experiments are allowed by the parser
    And a configuration file containing:
      """
      terraform {
        experiments = [old_feature]
      }
      """
    When the configuration is loaded
    Then an error diagnostic should be produced
    And the diagnostic summary should be "Experiment has concluded"
    And the diagnostic detail should be 'Experiment "old_feature" is no longer available. Use new_feature instead.'

  Scenario: Declaring an Unknown Experimental Feature
    Given language experiments are allowed by the parser
    And a configuration file containing:
      """
      terraform {
        experiments = [unknown_feature_keyword]
      }
      """
    When the configuration is loaded
    Then an error diagnostic should be produced
    And the diagnostic summary should be "Unknown experiment keyword"
    And the diagnostic detail should state 'There is no current experiment with the keyword "unknown_feature_keyword".'

  Scenario: Invalid Syntax for Experiments Argument
    Given language experiments are allowed by the parser
    And a configuration file containing:
      """
      terraform {
        experiments = "not_a_list"
      }
      """
    When the configuration is loaded
    Then an error diagnostic should be produced
    And the diagnostic summary should be "Invalid expression"
    And the diagnostic detail should state "A static list expression is required."

  Scenario: Attempting to Use Experimental Features When Disallowed
    Given language experiments are NOT allowed by the parser (e.g., release build)
    And a configuration file containing:
      """
      terraform {
        experiments = [current_feature]
      }
      """
    When the configuration is loaded
    Then an error diagnostic should be produced
    And the diagnostic summary should be "Module uses experimental features"
    And the diagnostic detail should explain that experiments are only for alpha releases

```

Notes:
*   The `Background` sets up mock experiment states.
*   Each scenario tests a specific condition related to the `experiments` block and the parser's configuration (`AllowLanguageExperiments`).
*   Diagnostic messages are matched closely with those in the Go test.

This covers `experiments_test.go`.

Next is `internal/configs/import_test.go`.
