# Metadata:
# Covers: internal/configs/config_build_test.go
# TestFunctions:
# - TestBuildConfig
# - TestBuildConfigDiags
# - TestBuildConfigChildModule_Backend
# - TestBuildConfigChildModule_CloudBlock
# - TestBuildConfigInvalidModules (representative cases)
# - TestBuildConfig_WithMockDataSources
# - TestBuildConfig_WithMockDataSourcesInline
# - TestBuildConfig_WithTestModule (and nested variant)

Feature: Configuration Tree Building (BuildConfig)
  This feature describes how Terraform constructs a complete configuration tree,
  including all modules and their relationships, from a parsed root module.
  It also covers error handling and special processing for test configurations.

  Background:
    Given a Terraform configuration parser
    And a mock module walker that can load child modules by source address (relative to a testdata directory)
    And a mock data loader for provider test data

  Scenario: Building a Configuration Tree with Nested and Shared Modules
    Given a root module configuration ("testdata/config-build") that calls:
      | Module Name | Source Path |
      | child_a     | ./child_a   |
      | child_b     | ./child_b   |
    And module "child_a" calls module "child_c" (source "./child_c")
    And module "child_b" also calls module "child_c" (source "./child_c")
    And the mock module walker assigns incremental versions (1.0.0, 1.0.1, ...) upon loading
    When the configuration tree is built from the root module
    Then no diagnostics should be produced
    And the configuration tree should contain the following module paths with their versions:
      | Path              | Version |
      | (root)            | (nil)   |
      | child_a           | 1.0.0   |
      | child_a.child_c   | 1.0.1   |
      | child_b           | 1.0.2   |
      | child_b.child_c   | 1.0.3   |
    And the module instance at path "child_a.child_c" should be distinct from "child_b.child_c"
    And both "child_a.child_c" and "child_b.child_c" should contain their defined outputs (e.g., "hello")

  Scenario: Error Propagation from Nested Modules During Config Build
    Given a root module configuration ("testdata/nested-errors") that calls "child_a"
    And module "child_a" calls "child_c"
    And module "child_c" (at "testdata/nested-errors/child_c/child_c.tf") contains an invalid block "invalid" at line 5
    When the configuration tree is built from the root module
    Then diagnostics should be produced
    And one diagnostic should indicate an "Unsupported block type" for "invalid" in "child_c/child_c.tf" at line 5
    And the partially built configuration tree should still contain:
      | Path            | Version |
      | (root)          | (nil)   |
      | child_a         | 1.0.0   |
      | child_a.child_c | 1.0.1   | # child_c node exists but might be marked as problematic

  Scenario Outline: Invalid Blocks in Child Modules
    Given a root module configuration that calls child module "child"
    And child module "child" contains a <BlockType> block
    When the configuration tree is built
    Then a warning diagnostic should be produced with summary "<DiagnosticSummary>"
    And the configuration tree including "child" should still be loaded

    Examples:
      | BlockType | DiagnosticSummary             | TestDataDirectory             |
      | backend   | Backend configuration ignored | testdata/nested-backend-warning |
      | cloud     | Cloud configuration ignored   | testdata/nested-cloud-warning   |

  Scenario Outline: Configuration Validation During Build Process (<ValidationRuleDescription>)
    Given a root module configuration from test directory "<TestDataDir>" (known to violate a rule)
    When the configuration tree is built
    Then error diagnostics should be produced containing "<ExpectedErrorMessagePart>"

    Examples: # Representative cases from TestBuildConfigInvalidModules
      | ValidationRuleDescription           | TestDataDir                             | ExpectedErrorMessagePart                                   |
      | Duplicate variable name             | testdata/config-diagnostics/var-duplicate | "Variable \"foo\" previously declared"                     |
      | Missing required provider attribute | testdata/config-diagnostics/provider-req-attr-missing | "The argument \"region\" is required, but no definition was found." |
      | Invalid module source address       | testdata/config-diagnostics/module-source-invalid | "Invalid module source address"                          |
      | Output referring to unknown value   | testdata/config-diagnostics/output-unknown-ref | "This object does not have an attribute named \"nonexistent\"." |

  Scenario: Loading Mock Data for Test Configurations
    Given a root module with a test file "main.tftest.hcl" for provider "aws"
    And the test file's provider block references external mock data from "mocks/" (containing mock_data_sources, mock_resources, overrides)
    When the configuration tree is built (including test configurations)
    Then no diagnostics should be produced
    And the "aws" provider configuration within the "main.tftest.hcl" test should contain the loaded mock data sources
    And it should contain the loaded mock resources
    And it should contain the loaded overrides

  Scenario: Inline Mock Data Overrides External Mock Data in Test Configurations
    Given a root module with a test file "main.tftest.hcl" for provider "aws"
    And the test file's provider block references external mock data AND defines inline mock_resources for "aws_s3_bucket"
    And the external mock data also defines defaults for "aws_s3_bucket"
    When the configuration tree is built (including test configurations)
    Then no diagnostics should be produced
    And the "aws_s3_bucket" mock resource defaults for the "aws" provider in the test should reflect the inline definition

  Scenario: Building Configuration for Test Run with Alternate Module Source
    Given a root module with a test file "main.tftest.hcl"
    And the test file defines a run block that sources the main configuration from module "./alternate_module"
    When the configuration tree is built (including test configurations and their specific runs)
    Then no diagnostics should be produced
    And the test run's ConfigUnderTest should represent the "./alternate_module"
    And if "./alternate_module" calls further child modules (e.g., "child"), their paths in the ConfigUnderTest tree should be relative to the new root (e.g., "child")

```

Notes:
*   `(root)` and `(nil)` are used for path/version of the actual root config.
*   `ModuleWalkerFunc` and `MockDataLoaderFunc` are abstracted into `Given` steps.
*   `TestBuildConfigInvalidModules` is highly data-driven. The BDD picks a few representative examples. A full BDD suite for *all* config validations would be enormous and better suited for the validation logic itself.
*   Test-related scenarios (`terraform test`) focus on the structural outcome of loading mocks and alternate module sources.

This covers `config_build_test.go`.

Next is `internal/configs/config_test.go`.
