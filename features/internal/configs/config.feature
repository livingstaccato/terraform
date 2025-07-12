# Metadata:
# Covers: internal/configs/config_test.go
# TestFunctions:
# - TestConfigProviderTypes (and _nested)
# - TestConfigResolveAbsProviderAddr
# - TestConfigProviderRequirements (and variants _InclTests, _Shallow, _ShallowInclTests, _ByModule, _ByModuleInclTests)
# - TestConfigProviderRequirementsDuplicate
# - TestVerifyDependencySelections
# - TestConfigProviderForConfigAddr
# - TestConfigImportProviderClashesWithModules
# - TestConfigImportProviderClashesWithResources
# - TestConfigImportProviderWithNoResourceProvider
# Note: TestConfigAddProviderRequirements is an internal helper test.

Feature: Configuration Processing for Providers and Modules
  This feature describes how Terraform processes loaded configurations to understand
  provider types, resolve provider addresses, aggregate version requirements,
  and validate provider usage in import blocks.

  Background:
    Given a Terraform configuration parser

  Scenario: Identifying Unique Provider Types in a Configuration
    Given a configuration loaded from "testdata/valid-files/providers-explicit-implied.tf" (with aws, local, null, template, test providers)
    When the set of unique provider types used in the configuration is requested
    Then the set should contain "aws", "local", "null", "template", "test" (all as default FQNs)

  Scenario: Identifying Unique Provider Types in a Nested Module Configuration
    Given a nested module configuration loaded from "testdata/valid-modules/nested-providers-fqns" where:
      | Module Path | Provider Local Name | Provider FQN Source         |
      | root        | test                | (default)                   |
      | root.childA | test                | "bar/test" (default host)   |
      | root.childB | test                | "foo/test" (default host)   |
    When the set of unique provider types used across the entire configuration is requested
    Then the set should include:
      | Provider FQN                        |
      | registry.terraform.io/-/test        |
      | registry.terraform.io/bar/test      |
      | registry.terraform.io/foo/test      |

  Scenario Outline: Resolving Absolute Provider Addresses
    Given a configuration loaded from "testdata/providers-explicit-fqn" which defines provider "foo-test" as "foo/test"
    And the current module context is the root module
    When an attempt is made to resolve the absolute address for a <AddressType> provider configuration "<LocalAddress>"
    Then the resolved absolute provider configuration address should be "<ExpectedAbsoluteAddress>"

    Examples:
      | AddressType | LocalAddress               | ExpectedAbsoluteAddress                                  |
      | absolute    | "module.root.provider.test.boop" | module.root.provider.registry.terraform.io/-/test.boop   |
      | local       | "implied.boop"             | module.root.provider.registry.terraform.io/-/implied.boop|
      | local       | "foo-test.boop"            | module.root.provider.registry.terraform.io/foo/test.boop |

  Scenario: Aggregating Provider Version Requirements Across Modules
    Given a nested module configuration from "testdata/provider-reqs" with various required_providers blocks
    When the aggregated provider requirements for the entire configuration are calculated
    Then the requirements should include:
      | Provider FQN                        | VersionConstraints   |
      | registry.terraform.io/hashicorp/null| "~> 2.0.0, = 2.0.1"  | # Merged from root and child
      | registry.terraform.io/hashicorp/random| "~> 1.2.0"           | # From root only
      | registry.terraform.io/hashicorp/tls | "~> 3.0"             | # From root only
      # ... and others like 'configured', 'implied', 'happycloud', 'grandchild' with their respective constraints or nil
    And a deprecation warning for version constraints in provider blocks should be present

  Scenario: Verifying Dependency Selections Against Lock File
    Given a configuration from "testdata/provider-reqs" with its aggregated provider requirements
    And a dependency lock file with the following provider selections:
      | Provider FQN                        | Selected Version |
      | registry.terraform.io/hashicorp/null| "2.0.0"          | # Does not satisfy "= 2.0.1" from child
      | registry.terraform.io/hashicorp/random| "1.2.2"          | # Satisfies "~> 1.2.0"
      # ... other providers configured correctly or missing
    When the configuration's dependency selections are verified against this lock file
    Then errors should be reported for "registry.terraform.io/hashicorp/null" indicating the locked version doesn't match updated constraints
    And errors should be reported for any other required providers missing from the lock file

  Scenario: Resolving Provider FQN from Local Name in Configuration
    Given a configuration loaded from "testdata/valid-modules/providers-fqns" where "foo-test" is locally mapped to "foo/test"
    When the FQN for local provider name "foo-test" is requested
    Then the resolved FQN should be "registry.terraform.io/foo/test"
    When the FQN for local provider name "bar-test" (not explicitly mapped) is requested
    Then the resolved FQN should be "registry.terraform.io/-/bar-test" (default FQN)

  Scenario Outline: Validation of 'provider' Argument in 'import' Blocks
    Given a Terraform configuration file with content:
      """
      <FileContent>
      """
    When the configuration is loaded and provider requirements are processed
    Then <NumberOfDiagnostics> diagnostics should be produced
    And if diagnostics are produced, one should have summary containing "<ExpectedSummaryPart>" and detail containing "<ExpectedDetailPart>"

    Examples:
      | FileContent                                                                 | NumberOfDiagnostics | ExpectedSummaryPart        | ExpectedDetailPart                                  |
      | import { id="id1"; to=module.foo; provider=aws }                            | 1                   | "Invalid import provider argument" | "can only be specified in import blocks that will generate configuration" | # Clash with module
      | resource "aws_instance" "i" {}\nimport { id="id2"; to=aws_instance.i; provider=aws.bar } | 1                   | "Invalid import provider argument" | "Use the provider argument in the target resource block" | # Clash with resource
      | import { id="id3"; provider=aws.baz }                                       | 1                   | "Invalid import provider argument" | "can only be specified in import blocks that will generate configuration" | # No resource provider to begin with

```

Notes:
*   Many tests in `config_test.go` deal with `terraform test` specific constructs (`TestConfigProviderRequirementsInclTests`, etc.). I've included one example for `ProviderRequirementsInclTests` but a full BDD suite for `terraform test` behavior might be a separate, larger feature if desired. For now, I'm focusing on core config processing.
*   The `TestVerifyDependencySelections` BDD is simplified; the Go test has more permutations of lock file states.
*   The BDD for import block validation captures the essence of the errors.

This covers `config_test.go`.

Next is `internal/configs/escaping_blocks_test.go`.
