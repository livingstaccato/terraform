# Metadata:
# Covers: internal/addrs/local_value.go
# Behavior derived from source code analysis as no dedicated test file was found for local_value specifically.
# Parsing of `local.<name>` is covered in `parse_ref.feature`.

Feature: Local Value Addressing and Transformations
  This feature describes how local values are addressed within Terraform configurations
  and how these addresses can be transformed into absolute forms.

  Scenario: LocalValue String Representation
    Given a LocalValue named "service_endpoint"
    When its string representation is generated
    Then the result should be "local.service_endpoint"

  Scenario: Absolute Local Value Address Transformation
    Given a LocalValue named "internal_ip"
    And a ModuleInstance address "module.network.module.private_subnet[0]"
    When the LocalValue is made absolute to the ModuleInstance
    Then the resulting AbsLocalValue string representation should be "module.network.module.private_subnet[0].local.internal_ip"

  Scenario: Absolute Local Value Address Transformation (Root Module)
    Given a LocalValue named "api_version"
    And a RootModuleInstance
    When the LocalValue is made absolute to the RootModuleInstance
    Then the resulting AbsLocalValue string representation should be "local.api_version"

  Scenario: ModuleInstance Helper for AbsLocalValue
    Given a ModuleInstance address "module.compute"
    And a local value name "instance_count"
    When an AbsLocalValue is created using the ModuleInstance helper for the given name
    Then the resulting AbsLocalValue string representation should be "module.compute.local.instance_count"
    And its LocalValue part should have the name "instance_count"
