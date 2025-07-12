# Metadata:
# Covers: internal/addrs/provider_test.go
# TestFunctions:
# - TestProviderString
# - TestProviderLegacyString
# - TestProviderDisplay
# - TestProviderIsDefaultProvider
# - TestProviderIsBuiltIn
# - TestProviderIsLegacy
# - TestParseProviderSourceStr
# - TestParseProviderPart
# - TestProviderEquals

Feature: Provider Identity Addressing and Parsing
  This feature describes how Terraform represents provider identities (hostname, namespace, type),
  generates various string forms for them, parses these strings, and checks provider characteristics.

  Scenario Outline: Canonical String Representation of Provider Identity
    Given a provider with hostname "<Hostname>", namespace "<Namespace>", and type "<Type>"
    When its canonical string representation is generated
    Then the result should be "<ExpectedFQTN>"

    Examples:
      | Hostname                    | Namespace | Type      | ExpectedFQTN                               |
      | registry.terraform.io       | hashicorp | test      | registry.terraform.io/hashicorp/test       |
      | registry.terraform.io       | hashicorp | test-beta | registry.terraform.io/hashicorp/test-beta  |
      | registry.terraform.com      | hashicorp | test      | registry.terraform.com/hashicorp/test      |
      | registry.terraform.io       | othercorp | test      | registry.terraform.io/othercorp/test       |

  Scenario Outline: Legacy String Representation of Provider Identity
    Given a provider with hostname "<Hostname>", namespace "<Namespace>", and type "<Type>"
    When its legacy string representation is generated
    Then the result should be "<ExpectedLegacyString>"

    Examples:
      | Hostname              | Namespace | Type      | ExpectedLegacyString |
      | registry.terraform.io | -         | test      | test                 | # Legacy namespace implies short form
      | (BuiltIn)             | (BuiltIn) | terraform | terraform            | # BuiltIn implies short form

  Scenario Outline: Display String Representation of Provider Identity
    Given a provider with hostname "<Hostname>", namespace "<Namespace>", and type "<Type>"
    When its display string representation is generated
    Then the result should be "<ExpectedDisplayString>"

    Examples:
      | Hostname                    | Namespace | Type | ExpectedDisplayString                     |
      | registry.terraform.io       | hashicorp | test | hashicorp/test                            | # Default hostname omitted
      | registry.terraform.com      | hashicorp | test | registry.terraform.com/hashicorp/test     |
      | registry.terraform.io       | othercorp | test | othercorp/test                            | # Default hostname omitted

  Scenario Outline: Checking Provider Characteristics
    Given a provider with hostname "<Hostname>", namespace "<Namespace>", and type "<Type>"
    When I check if it is a default provider
    Then the result should be <IsDefault>
    When I check if it is a built-in provider
    Then the result should be <IsBuiltIn>
    When I check if it is a legacy provider
    Then the result should be <IsLegacy>

    Examples:
      | Hostname                    | Namespace | Type | IsDefault | IsBuiltIn | IsLegacy |
      | registry.terraform.io       | hashicorp | test | true      | false     | false    |
      | registry.terraform.com      | hashicorp | test | false     | false     | false    |
      | registry.terraform.io       | othercorp | test | false     | false     | false    |
      | (BuiltIn)                   | (BuiltIn) | test | false     | true      | false    |
      | registry.terraform.io       | -         | test | false     | false     | true     |

  Scenario Outline: Parsing Valid Provider Source Strings
    Given a provider source string "<SourceString>"
    When it is parsed
    Then the parsing should be successful
    And the resulting provider should have hostname "<ExpectedHostname>", namespace "<ExpectedNamespace>", and type "<ExpectedType>"

    Examples:
      | SourceString                          | ExpectedHostname          | ExpectedNamespace | ExpectedType |
      | registry.terraform.io/hashicorp/aws   | registry.terraform.io     | hashicorp         | aws          |
      | registry.Terraform.io/HashiCorp/AWS   | registry.terraform.io     | hashicorp         | aws          | # Case-insensitivity
      | hashicorp/aws                         | registry.terraform.io     | hashicorp         | aws          | # Shorthand
      | aws                                   | registry.terraform.io     | hashicorp         | aws          | # Shortest shorthand
      | example.com/foo-bar/baz-boop          | example.com               | foo-bar           | baz-boop     |
      | localhost:8080/foo/bar                | localhost:8080            | foo               | bar          |

  Scenario Outline: Parsing Invalid Provider Source Strings
    Given a provider source string "<SourceString>"
    When it is parsed
    Then the parsing should fail

    Examples:
      | SourceString                             |
      | example.com/too/many/parts/here          |
      | /too///many//slashes                     |
      | ///                                      |
      | badhost!/hashicorp/aws                   |
      | example.com/badnamespace!/aws            |
      | example.com/hashicorp/badtype!           |
      | example.com/hashicorp/terraform-provider-bad | # Reserved prefix
      | example.com/hashicorp/terraform-bad      | # Reserved prefix

  Scenario Outline: Parsing and Normalizing Provider Name Parts
    Given a provider name part string "<PartString>"
    When it is parsed as a provider name part
    Then the parsing result should be "<ExpectedResult>"
    And if successful, the normalized part should be "<NormalizedPart>"
    And if failed, the error should contain "<ErrorMessage>"

    Examples:
      | PartString  | ExpectedResult | NormalizedPart | ErrorMessage                                                                |
      | FOO         | success        | foo            |                                                                             |
      | abc-123     | success        | abc-123        |                                                                             |
      | Испытание   | success        | испытание      |                                                                             | # Unicode
      | münchen    | success        | münchen        |                                                                             | # Unicode normalization (combining diaeresis)
      | abc--123    | failure        |                | cannot use multiple consecutive dashes                                      |
      | abc.123     | failure        |                | dots are not allowed                                                        |
      | -abc123     | failure        |                | must contain only letters, digits, and dashes, and may not use leading or trailing dashes |
      |             | failure        |                | must have at least one character                                            |

  Scenario Outline: Provider Identity Equality Comparison
    Given a provider "P1" with hostname "<H1>", namespace "<N1>", and type "<T1>"
    And another provider "P2" with hostname "<H2>", namespace "<N2>", and type "<T2>"
    When I compare provider "P1" with provider "P2" for equality
    Then the result should be <AreEqual>

    Examples:
      | H1                    | N1        | T1   | H2                    | N2        | T2      | AreEqual |
      | registry.terraform.io | foo       | test | registry.terraform.io | foo       | test    | true     |
      | registry.terraform.io | foo       | test | registry.terraform.io | bar       | test    | false    | # Diff namespace
      | registry.terraform.io | foo       | test | registry.terraform.io | foo       | my-test | false    | # Diff type
      | registry.terraform.io | foo       | test | example.com           | foo       | test    | false    | # Diff hostname

```

Notes for this Gherkin:

*   Special values like `(BuiltIn)` for hostname/namespace and `-` for legacy namespace are used for clarity in the tables.
*   The "Parsing Invalid Provider Source Strings" scenario groups various failure cases. Specific error messages aren't detailed here for brevity, but the Go test checks them.
*   `ParseProviderPart` has its own scenario detailing success/failure and normalization, as it's a distinct utility function.
*   The Gherkin attempts to cover the different functionalities (string generation, parsing, classification, equality) tested in the Go file.

The next file is `internal/addrs/resource_test.go`.
