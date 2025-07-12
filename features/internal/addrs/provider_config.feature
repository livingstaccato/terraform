# Metadata:
# Covers: internal/addrs/provider_config_test.go
# TestFunctions:
# - TestParseAbsProviderConfig
# - TestAbsProviderConfigString
# - TestAbsProviderConfigLegacyString
# - TestParseLegacyAbsProviderConfigStr

Feature: Absolute Provider Configuration Addressing
  This feature describes how Terraform parses, represents, and handles addresses
  for specific provider configurations, including default and aliased configurations,
  both in current and legacy formats.

  Scenario Outline: Parsing Valid Absolute Provider Configuration Addresses
    Given an HCL traversal string "<TraversalString>" for an absolute provider configuration
    When it is parsed
    Then the parsing should be successful
    And the resulting provider configuration should be for provider type "<ProviderType>" with namespace "<Namespace>" and hostname "<Hostname>"
    And it should be in module "<ModulePath>"
    And its alias should be "<Alias>"

    Examples:
      | TraversalString                                               | ModulePath | ProviderType | Namespace | Hostname              | Alias |
      | provider["registry.terraform.io/hashicorp/aws"]               | (Root)     | aws          | hashicorp | registry.terraform.io |       |
      | provider["registry.terraform.io/hashicorp/aws"].foo           | (Root)     | aws          | hashicorp | registry.terraform.io | foo   |
      | module.baz.provider["registry.terraform.io/hashicorp/aws"]    | module.baz | aws          | hashicorp | registry.terraform.io |       |
      | module.baz.provider["registry.terraform.io/hashicorp/aws"].foo| module.baz | aws          | hashicorp | registry.terraform.io | foo   |

  Scenario Outline: Parsing Invalid Absolute Provider Configuration Addresses
    Given an HCL traversal string "<TraversalString>" for an absolute provider configuration
    When it is parsed
    Then the parsing should fail with an error containing "<ExpectedErrorMessage>"

    Examples:
      | TraversalString                                                      | ExpectedErrorMessage                                                              |
      | module.baz["foo"].provider["registry.terraform.io/hashicorp/aws"]    | Provider address cannot contain module indexes                                    |
      | module.baz[1].provider["registry.terraform.io/hashicorp/aws"]        | Provider address cannot contain module indexes                                    |
      | aws                                                                  | Provider address must begin with "provider.", followed by a provider type name. |
      | provider                                                             | Provider address must begin with "provider.", followed by a provider type name. |
      | provider.aws.foo.bar                                                 | Extraneous operators after provider configuration alias.                          |
      | provider["aws"]["foo"]                                               | Provider type name must be followed by a configuration alias name.                | # Should be provider["aws"].foo
      | provider[0]                                                          | The prefix "provider." must be followed by a provider type name.                  |

  Scenario Outline: Standard String Representation of Absolute Provider Configurations
    Given an absolute provider configuration in module "<ModulePath>" for provider type "<ProviderType>" with namespace "<Namespace>" and hostname "<Hostname>" and alias "<Alias>"
    When its standard string representation is generated
    Then the result should be "<ExpectedString>"

    Examples:
      | ModulePath        | ProviderType | Namespace | Hostname              | Alias | ExpectedString                                                              |
      | (Root)            | foo          | -         | registry.terraform.io |       | provider["registry.terraform.io/-/foo"]                                    | # Legacy provider example
      | module.child_module | foo          | hashicorp | registry.terraform.io |       | module.child_module.provider["registry.terraform.io/hashicorp/foo"]         | # Default provider
      | (Root)            | foo          | hashicorp | registry.terraform.io | bar   | provider["registry.terraform.io/hashicorp/foo"].bar                         |
      | module.child_module | foo          | hashicorp | registry.terraform.io | bar   | module.child_module.provider["registry.terraform.io/hashicorp/foo"].bar     |

  Scenario Outline: Legacy String Representation of Absolute Provider Configurations
    Given an absolute provider configuration in module "<ModulePath>" for provider type "<ProviderType>" (legacy, namespace assumed '-') and alias "<Alias>"
    When its legacy string representation is generated
    Then the result should be "<ExpectedString>"

    Examples:
      | ModulePath        | ProviderType | Alias | ExpectedString                          |
      | (Root)            | foo          |       | provider.foo                            |
      | module.child_module | foo          |       | module.child_module.provider.foo        |
      | (Root)            | foo          | bar   | provider.foo.bar                        |
      | module.child_module | foo          | bar   | module.child_module.provider.foo.bar    |

  Scenario Outline: Parsing Legacy Absolute Provider Configuration Strings
    Given a legacy address string "<LegacyString>" for an absolute provider configuration
    When it is parsed as a legacy provider configuration
    Then the parsing should be successful
    And the resulting provider configuration should be for provider type "<ProviderType>" with namespace "<Namespace>" and hostname "<Hostname>"
    And it should be in module "<ModulePath>"
    And its alias should be "<Alias>"

    Examples:
      | LegacyString                       | ModulePath        | ProviderType | Namespace | Hostname              | Alias |
      | provider.foo                       | (Root)            | foo          | -         | registry.terraform.io |       |
      | module.child_module.provider.foo   | module.child_module | foo          | -         | registry.terraform.io |       |
      | provider.terraform                 | (Root)            | terraform    | hashicorp | (BuiltIn)             |       | # Built-in provider

```

Notes for this Gherkin:

*   `(Root)` is used for `ModulePath` to signify `RootModule`.
*   For provider FQTNs (Fully Qualified Type Names), I've broken them down into `<ProviderType>`, `<Namespace>`, and `<Hostname>` for clarity in the "Given" steps of parsing and the "Then" steps of validation. A namespace of `-` is typical for legacy providers. A hostname of `(BuiltIn)` can signify providers like `terraform`.
*   The "Alias" column is empty if there's no alias.
*   The Gherkin distinguishes between standard and legacy string representations and their respective parsing methods.

The next file is `internal/addrs/provider_test.go`.
