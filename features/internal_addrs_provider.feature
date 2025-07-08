# Source Go File: internal/addrs/provider.go
# Source Go Test: internal/addrs/provider_test.go

Feature: Provider Addressing and Parsing
  This feature describes how Terraform provider addresses (addrs.Provider) are
  represented, parsed from strings, stringified into various formats, and categorized
  (e.g., default, legacy, built-in).

  Background:
    Given the Terraform addressing system for providers

  Scenario Outline: Parsing provider source strings
    Given a provider source string "<SourceString>"
    When ParseProviderSourceString is called
    Then the resulting Provider should have Hostname "<Hostname>", Namespace "<Namespace>", and Type "<Type>"
    And parsing should <SucceedOrError>
    And if it errors, the error message should contain "<ErrorMessageHint>"

    Examples:
      | SourceString                            | Hostname                  | Namespace | Type      | SucceedOrError | ErrorMessageHint |
      | "registry.terraform.io/hashicorp/aws"   | "registry.terraform.io"   | "hashicorp" | "aws"     | succeed        | ""               |
      | "registry.Terraform.io/HashiCorp/AWS"   | "registry.terraform.io"   | "hashicorp" | "aws"     | succeed        | ""               | # Case-insensitivity and normalization
      | "hashicorp/aws"                         | "registry.terraform.io"   | "hashicorp" | "aws"     | succeed        | ""               | # Default hostname
      | "aws"                                   | "registry.terraform.io"   | "hashicorp" | "aws"     | succeed        | ""               | # Default hostname and namespace
      | "example.com/foo-bar/baz-boop"          | "example.com"             | "foo-bar" | "baz-boop"| succeed        | ""               |
      | "localhost:8080/foo/bar"                | "localhost:8080"          | "foo"     | "bar"     | succeed        | ""               |
      | "example.com/too/many/parts/here"       | ""                        | ""        | ""        | error          | "too many parts" |
      | "badhost!/hashicorp/aws"                | ""                        | ""        | ""        | error          | "invalid hostname" |
      | "example.com/bad.namespace/aws"         | ""                        | ""        | ""        | error          | "invalid namespace" |
      | "example.com/hashicorp/badtype!"        | ""                        | ""        | ""        | error          | "invalid type"   |
      | "example.com/hashicorp/terraform-bad"   | ""                        | ""        | ""        | error          | "reserved prefix"|

  Scenario Outline: Provider string representations
    Given a Provider with Hostname "<Hostname>", Namespace "<Namespace>", and Type "<Type>"
    When its String() method is called, the result should be "<ExpectedString>"
    When its LegacyString() method is called (if applicable), the result should be "<ExpectedLegacyString>"
    When its ForDisplay() method is called, the result should be "<ExpectedForDisplayString>"

    Examples:
      # Hostname, Namespace, Type, ExpectedString, ExpectedLegacyString, ExpectedForDisplayString
      | "registry.terraform.io" | "hashicorp" | "test"      | "registry.terraform.io/hashicorp/test" | "test" (if legacy ns) | "hashicorp/test"          |
      | "registry.terraform.io" | "-"         | "test"      | "registry.terraform.io/-/test"         | "test"                | "-/test"                  | # Legacy
      | "terraform.local"       | "-"         | "terraform" | "terraform.local/-/terraform"          | "terraform"           | "-/terraform"             | # BuiltIn
      | "registry.terraform.com"| "hashicorp" | "test"      | "registry.terraform.com/hashicorp/test"| ""                    | "registry.terraform.com/hashicorp/test" |
      | "registry.terraform.io" | "othercorp" | "test"      | "registry.terraform.io/othercorp/test" | ""                    | "othercorp/test"          |

  Scenario Outline: Provider categorization
    Given a Provider with Hostname "<Hostname>", Namespace "<Namespace>", and Type "<Type>"
    Then IsDefaultProvider should return <IsDefault>
    And IsBuiltIn should return <IsBuiltIn>
    And IsLegacy should return <IsLegacy>

    Examples:
      # Hostname, Namespace, Type, IsDefault, IsBuiltIn, IsLegacy
      | "registry.terraform.io" | "hashicorp" | "test"      | true    | false     | false    |
      | "registry.terraform.com"| "hashicorp" | "test"      | false   | false     | false    |
      | "registry.terraform.io" | "othercorp" | "test"      | false   | false     | false    |
      | "terraform.local"       | "-"         | "terraform" | false   | true      | false    | # BuiltInProviderNamespace is "-"
      | "registry.terraform.io" | "-"         | "test"      | false   | false     | true     | # LegacyProviderNamespace is "-"

  Scenario Outline: Provider equality
    Given Provider A with Hostname "<HostA>", Namespace "<NsA>", Type "<TypeA>"
    And Provider B with Hostname "<HostB>", Namespace "<NsB>", Type "<TypeB>"
    When Provider A is compared with Provider B using Equals()
    Then the result should be <IsEqual>

    Examples:
      | HostA | NsA | TypeA | HostB | NsB | TypeB | IsEqual |
      | "registry.terraform.io" | "foo" | "test" | "registry.terraform.io" | "foo" | "test" | true    |
      | "registry.terraform.io" | "foo" | "test" | "registry.terraform.io" | "bar" | "test" | false   |
      | "registry.terraform.io" | "foo" | "test" | "example.com"           | "foo" | "test" | false   |

  # Note:
  # - DefaultProviderRegistryHost is "registry.terraform.io".
  # - DefaultProviderNamespace is "hashicorp".
  # - LegacyProviderNamespace is "-".
  # - BuiltInProviderHost is "terraform.local", BuiltInProviderNamespace is "-".
  # - Step definitions need to handle these constants and create addrs.Provider instances.
  # - The cty aspects are minimal here; this feature focuses on the structure and string representations of Provider addresses.
  # - ParseProviderPart is an internal helper but its logic (validation of name parts) is implicitly tested by ParseProviderSourceString.
  # - ForDisplay format omits default hostname.
  # - LegacyString format is simpler for legacy/built-in providers.
  # - String() is the canonical FQN.
