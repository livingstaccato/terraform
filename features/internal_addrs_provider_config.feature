# Source Go File: internal/addrs/provider_config.go
# Source Go Test: internal/addrs/provider_config_test.go

Feature: Absolute Provider Configuration Addressing
  This feature describes how Terraform absolute provider configurations (AbsProviderConfig)
  are represented, parsed from HCL traversals or strings, stringified into
  modern and legacy formats, and compared.

  Background:
    Given the Terraform addressing system for provider configurations

  Scenario Outline: Parsing HCL traversal to AbsProviderConfig (Successful Cases)
    Given an HCL traversal string "<TraversalString>"
    When ParseAbsProviderConfig is called with the parsed traversal
    Then the resulting AbsProviderConfig should have Module Path "<ExpectedModulePath>", Provider Type "<ProviderType>", Namespace "<ProviderNS>", Hostname "<ProviderHost>", and Alias "<Alias>"
    And no parsing error should occur

    Examples:
      | TraversalString                                                    | ExpectedModulePath | ProviderType | ProviderNS | ProviderHost          | Alias |
      | provider["registry.terraform.io/hashicorp/aws"]                    | ""                 | "aws"        | "hashicorp"| "registry.terraform.io" | ""    |
      | provider["registry.terraform.io/hashicorp/aws"].foo                | ""                 | "aws"        | "hashicorp"| "registry.terraform.io" | "foo" |
      | module.baz.provider["registry.terraform.io/hashicorp/aws"]         | "module.baz"       | "aws"        | "hashicorp"| "registry.terraform.io" | ""    |
      | module.baz.provider["registry.terraform.io/hashicorp/aws"].foo     | "module.baz"       | "aws"        | "hashicorp"| "registry.terraform.io" | "foo" |

  Scenario Outline: Parsing HCL traversal to AbsProviderConfig (Failure Cases)
    Given an HCL traversal string "<TraversalString>"
    When ParseAbsProviderConfig is called with the parsed traversal
    Then a diagnostic should occur with detail message containing "<ExpectedErrorDetail>"

    Examples:
      | TraversalString                                                              | ExpectedErrorDetail                                                                 |
      | module.baz["foo"].provider["registry.terraform.io/hashicorp/aws"]            | Provider address cannot contain module indexes                                      |
      | module.baz[1].provider["registry.terraform.io/hashicorp/aws"]                | Provider address cannot contain module indexes                                      |
      | aws                                                                          | Provider address must begin with "provider.", followed by a provider type name. |
      | provider                                                                     | Provider address must begin with "provider.", followed by a provider type name. |
      | provider.aws.foo.bar                                                         | Extraneous operators after provider configuration alias.                            |
      | provider["aws"]["foo"]                                                       | Provider type name must be followed by a configuration alias name.                  | # Legacy format not parsable by ParseAbsProviderConfig
      | provider[0]                                                                  | The prefix "provider." must be followed by a provider type name.                    |

  Scenario Outline: String representation of AbsProviderConfig (Modern Format)
    Given an AbsProviderConfig with Module Path "<ModulePath>", Provider Type "<ProviderType>", Namespace "<ProviderNS>", Hostname "<ProviderHost>", and Alias "<Alias>"
    When its String() method is called
    Then the result should be "<ExpectedString>"

    Examples:
      | ModulePath         | ProviderType | ProviderNS | ProviderHost          | Alias | ExpectedString                                                              |
      | ""                 | "foo"        | "-"        | "registry.terraform.io" | ""    | provider["registry.terraform.io/-/foo"]                                     | # Legacy provider
      | "module.child_module" | "foo"        | "hashicorp"| "registry.terraform.io" | ""    | module.child_module.provider["registry.terraform.io/hashicorp/foo"]         |
      | ""                 | "foo"        | "hashicorp"| "registry.terraform.io" | "bar" | provider["registry.terraform.io/hashicorp/foo"].bar                         |
      | "module.child_module" | "foo"        | "hashicorp"| "registry.terraform.io" | "bar" | module.child_module.provider["registry.terraform.io/hashicorp/foo"].bar     |

  Scenario Outline: String representation of AbsProviderConfig (Legacy Format)
    Given an AbsProviderConfig with Module Path "<ModulePath>", Provider Type "<ProviderType>" (legacy, so NS/Host are implied default), and Alias "<Alias>"
    When its LegacyString() method is called
    Then the result should be "<ExpectedLegacyString>"

    Examples:
      | ModulePath         | ProviderType | Alias | ExpectedLegacyString                     |
      | ""                 | "foo"        | ""    | provider.foo                             |
      | "module.child_module" | "foo"        | ""    | module.child_module.provider.foo         |
      | ""                 | "foo"        | "bar" | provider.foo.bar                         |
      | "module.child_module" | "foo"        | "bar" | module.child_module.provider.foo.bar     |

  Scenario Outline: Parsing legacy string to AbsProviderConfig
    Given a legacy provider address string "<LegacyAddressString>"
    When ParseLegacyAbsProviderConfigStr is called with this string
    Then the resulting AbsProviderConfig should have Module Path "<ExpectedModulePath>", Provider Type "<ProviderType>", and Alias "<Alias>"
    And the Provider should be a LegacyProvider or BuiltInProvider as appropriate

    Examples:
      | LegacyAddressString                | ExpectedModulePath | ProviderType | Alias | ProviderKind      |
      | provider.foo                       | ""                 | "foo"        | ""    | LegacyProvider    |
      | module.child_module.provider.foo   | "module.child_module" | "foo"        | ""    | LegacyProvider    |
      | provider.terraform                 | ""                 | "terraform"  | ""    | BuiltInProvider   |

  # Note:
  # - ModulePath is a string representation of an addrs.Module.
  # - ProviderType, ProviderNS, ProviderHost, Alias are components of addrs.Provider and AbsProviderConfig.
  # - Step definitions will need to parse these strings into appropriate addrs types.
  # - The cty aspects are minimal here, mainly that provider configurations themselves (not their addresses)
  #   are represented as cty.Value, and these addresses point to those configurations.
  # - This feature focuses on the parsing and stringification of the addresses themselves.
  # - ProviderKind is a conceptual way to distinguish between NewLegacyProvider and NewBuiltInProvider results.
