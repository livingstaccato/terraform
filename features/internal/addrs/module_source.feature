# Metadata:
# Covers: internal/addrs/module_source.go
# Note: Parsing of module source strings is handled externally (e.g., in 'moduleaddrs' package)
# and BDD for parsing should be associated with that package. This feature focuses on
# string representations and specific methods of the ModuleSource types defined here.

Feature: Module Source Address Representation and Combination
  This feature describes how different types of module source addresses
  (local, registry, remote) are represented as strings and how remote sources
  derived from a registry are combined with user-specified subdirectory information.

  Scenario: ModuleSourceLocal String Representation
    Given a local module source with path "./my-local-module"
    When its string representation is generated
    Then the result should be "./my-local-module"
    When its display string representation is generated
    Then the result should be "./my-local-module"

  Scenario Outline: ModuleSourceRegistry String Representations
    Given a module registry package with hostname "<Host>", namespace "<NS>", name "<Name>"
    And a subdirectory "<Subdir>"
    When its canonical string representation is generated
    Then the result should be "<CanonicalString>"
    When its display string representation is generated
    Then the result should be "<DisplayString>"

    Examples:
      | Host                    | NS        | Name   | Subdir      | CanonicalString                             | DisplayString                    |
      | registry.terraform.io   | hashicorp | consul |             | registry.terraform.io/hashicorp/consul      | hashicorp/consul                 |
      | registry.terraform.io   | hashicorp | consul | modules/vpc | registry.terraform.io/hashicorp/consul//modules/vpc | hashicorp/consul//modules/vpc    |
      | my.custom.registry      | acme      | network|             | my.custom.registry/acme/network             | my.custom.registry/acme/network  |
      | my.custom.registry      | acme      | network| infra       | my.custom.registry/acme/network//infra      | my.custom.registry/acme/network//infra |

  Scenario Outline: ModuleSourceRemote String Representations
    Given a remote module source with package URL "<PackageURL>"
    And a subdirectory "<Subdir>"
    When its string representation is generated
    Then the result should be "<ExpectedString>"
    When its display string representation is generated (which is same as string for remote)
    Then the result should be "<ExpectedString>"

    Examples:
      | PackageURL                               | Subdir    | ExpectedString                                  |
      | git::https://example.com/repo.git        |           | git::https://example.com/repo.git               |
      | git::https://example.com/repo.git        | modules/m1| git::https://example.com/repo.git//modules/m1   |
      | s3::my-bucket/modules.zip?aws_profile=tf |           | s3::my-bucket/modules.zip?aws_profile=tf        |
      | s3::my-bucket/modules.zip?aws_profile=tf | app       | s3::my-bucket/modules.zip//app?aws_profile=tf   | # Subdir inserted before query

  Scenario Outline: Combining Remote Source with User-Given Registry Subdirectory (FromRegistry)
    Given a ModuleSourceRemote "Remote" with package URL "<RemotePackageURL>" and subdirectory "<RemoteSubdir>"
    And a ModuleSourceRegistry "GivenRegistry" with package "<GivenRegistryPackage>" and subdirectory "<GivenRegistrySubdir>"
    When the "Remote" source is adjusted based on the "GivenRegistry" source using FromRegistry
    Then the resulting ModuleSourceRemote should have package URL "<ExpectedPackageURL>"
    And its subdirectory should be "<ExpectedCombinedSubdir>"

    Examples:
      # No subdirs initially
      | RemotePackageURL | RemoteSubdir | GivenRegistryPackage      | GivenRegistrySubdir | ExpectedPackageURL | ExpectedCombinedSubdir |
      | git::foo.git     |              | registry/ns/name          |                     | git::foo.git       |                        |
      # Only remote has subdir
      | git::foo.git     | remote_sub   | registry/ns/name          |                     | git::foo.git       | remote_sub             |
      # Only given registry has subdir
      | git::foo.git     |              | registry/ns/name          | given_sub           | git::foo.git       | given_sub              |
      # Both have subdirs
      | git::foo.git     | remote_sub   | registry/ns/name          | given_sub           | git::foo.git       | remote_sub/given_sub   | # Paths are joined
