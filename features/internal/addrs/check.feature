# Metadata:
# Covers: internal/addrs/check.go
# Behavior derived from source code analysis.

Feature: Check Block Addressing and Properties
  This feature describes how 'check' blocks are addressed in Terraform configurations,
  how these addresses are represented and transformed, and their role as checkable entities.

  Scenario: Check Address String Representation and Equality
    Given a Check named "api_health"
    When its string representation is generated
    Then the result should be "check.api_health"

    Given a Check "C1" named "api_health"
    And a Check "C2" named "api_health"
    When I compare Check "C1" and "C2" for equality
    Then they should be equal

    Given a Check "C1" named "api_health"
    And a Check "C2" named "db_conn_check"
    When I compare Check "C1" and "C2" for equality
    Then they should NOT be equal

  Scenario: ConfigCheck Address Transformation and String Representation
    Given a Check named "api_health"
    And a Module configuration path "module.network"
    When the Check is associated with the Module configuration path to form a ConfigCheck
    Then the resulting ConfigCheck string representation should be "module.network.check.api_health"

    Given a Check named "root_check"
    And a RootModule configuration path
    When the Check is associated with the RootModule configuration path to form a ConfigCheck
    Then the resulting ConfigCheck string representation should be "check.root_check"

  Scenario: AbsCheck Address Transformation and String Representation
    Given a Check named "api_health"
    And a ModuleInstance address "module.network[0]"
    When the Check is made absolute to the ModuleInstance to form an AbsCheck
    Then the resulting AbsCheck string representation should be "module.network[0].check.api_health"

    Given a Check named "root_check"
    And a RootModuleInstance
    When the Check is made absolute to the RootModuleInstance to form an AbsCheck
    Then the resulting AbsCheck string representation should be "check.root_check"

  Scenario: Deriving CheckRule Address from AbsCheck
    Given an AbsCheck for "check.data_validation" in module instance "module.app"
    When a CheckRule address for type "CheckDataResource" with index 0 is derived
    Then its string representation should be "module.app.check.data_validation.data"
    When a CheckRule address for type "CheckAssertion" with index 0 is derived
    Then its string representation should be "module.app.check.data_validation.assert[0]"
    When a CheckRule address for type "CheckAssertion" with index 1 is derived
    Then its string representation should be "module.app.check.data_validation.assert[1]"

  Scenario: Checkable Properties of AbsCheck
    Given an AbsCheck for "check.security_scan" in module instance "module.security"
    When its CheckableKind is requested
    Then it should be "CheckableCheck"
    When its ConfigCheckable representation (a ConfigCheck) is requested
    Then its string representation should be "module.security.check.security_scan"
    And its CheckableKind should also be "CheckableCheck"

  Scenario: Checkable Properties of ConfigCheck
    Given a ConfigCheck for "check.style_guide" in module configuration "module.docs"
    When its CheckableKind is requested
    Then it should be "CheckableCheck"

  Scenario: Check Blocks and Meta-Arguments
    Given the current Terraform addressing for 'check' blocks
    Then 'check' blocks do not support 'count' or 'for_each' meta-arguments
    And therefore, a Check address within a module uniquely identifies a single check block

```

This covers the core functionalities defined in `check.go`.

Next on the list of `.go` files to analyze from `internal/addrs/` is `checkable.go`.
