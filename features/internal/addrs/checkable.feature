# Metadata:
# Covers: internal/addrs/checkable.go (specifically ParseCheckableStr)
# Behavior derived from source code analysis.

Feature: Parsing String Representations of Checkable Addresses
  This feature describes how Terraform parses string representations of 'Checkable'
  addresses, which are used internally, potentially for persisting check results.
  The parsing requires knowing the 'kind' of checkable address expected.

  Scenario Outline: Successfully Parsing Checkable Address Strings
    Given a checkable address string "<AddrString>"
    And the expected checkable kind is "<Kind>"
    When the string is parsed as a checkable address
    Then the parsing should be successful
    And the resulting checkable address should have a string representation matching "<AddrString>"
    And its CheckableKind should be "<Kind>"
    And if module-prefixed, its module path should be "<ExpectedModulePath>"
    And its base name should be "<ExpectedName>"
    And if it is a resource kind, its instance key should be "<ExpectedResourceInstanceKey>"

    Examples:
      # CheckableResource
      | AddrString                                       | Kind                | ExpectedModulePath      | ExpectedName | ExpectedResourceInstanceKey |
      | resource.aws_instance.web                        | CheckableResource   | (Root)                  | web          | (NoKey)                     |
      | data.aws_ami.ubuntu                              | CheckableResource   | (Root)                  | ubuntu       | (NoKey)                     |
      | module.app.resource.aws_instance.web             | CheckableResource   | module.app              | web          | (NoKey)                     |
      | module.app[0].resource.aws_instance.web          | CheckableResource   | module.app[0]           | web          | (NoKey)                     |
      | module.app[0].resource.aws_instance.web[1]       | CheckableResource   | module.app[0]           | web          | IntKey:1                    |
      | module.app[0].resource.aws_instance.web["key"]   | CheckableResource   | module.app[0]           | web          | StringKey:key               |
      # CheckableOutputValue
      | output.api_url                                   | CheckableOutputValue| (Root)                  | api_url      |                             |
      | module.network.output.vpc_id                     | CheckableOutputValue| module.network          | vpc_id       |                             |
      # CheckableCheck
      | check.db_connectivity                            | CheckableCheck      | (Root)                  | db_connectivity |                           |
      | module.service.check.health_status               | CheckableCheck      | module.service          | health_status |                           |
      # CheckableInputVariable
      | var.region                                       | CheckableInputVariable | (Root)                  | region       |                             |
      | module.vpc.var.cidr_block                        | CheckableInputVariable | module.vpc              | cidr_block   |                             |

  Scenario Outline: Failing to Parse Invalid Checkable Address Strings
    Given a checkable address string "<AddrString>"
    And the expected checkable kind is "<Kind>"
    When the string is parsed as a checkable address
    Then the parsing should fail with an error containing "<ExpectedErrorMessage>"

    Examples:
      # General errors
      | AddrString                               | Kind                | ExpectedErrorMessage                                                            |
      | module.app                               | CheckableResource   | Module path must be followed by either a resource instance address or an output value address. | # Incomplete for resource
      | module.app.output                        | CheckableOutputValue| OutputValue address must have only one attribute part after the keyword 'output'  | # Missing name
      | module.app.resource.type_only            | CheckableResource   | A resource name is required.                                                    |
      # Kind mismatch / keyword errors
      | module.app.output.name                   | CheckableResource   | Resource address must begin with a resource type name or "data.[type]".         | # Expected resource, got output keyword
      | module.app.resource.aws_instance.web     | CheckableOutputValue| OutputValue address must follow the module address with the keyword 'output'.     | # Expected output, got resource
      | module.app.var.my_var                    | CheckableCheck      | CheckBlock address must follow the module address with the keyword 'check'.       |
      | module.app.check.my_check                | CheckableInputVariable | VariableValue address must follow the module address with the keyword 'var'.        |
      # Malformed resource parts (detailed errors from underlying resource parsing)
      | resource.                                | CheckableResource   | A resource type is required.                                                    |
      | data.                                    | CheckableResource   | A data source type is required.                                                 |

```

Notes for this Gherkin:
*   The `ParseCheckableStr` function takes `kind CheckableKind` as an argument. This is reflected in the "Given" steps.
*   The "ExpectedModulePath" and "ExpectedName" are included for validation of successful parsing, where applicable. `(Root)` implies `RootModuleInstance`.
*   Error messages in the failure scenarios are based on the logic in `ParseCheckableStr` and the underlying parsers it calls.

Next non-test `.go` files to analyze from `internal/addrs/`:
*   `count_attr.go`
*   `doc.go`
*   `for_each_attr.go`
*   `local_value.go`
*   `module_package.go`
*   `module_source.go`
*   `move_endpoint_kind.go` (likely an enum)
*   `moveable.go` (likely an interface)
*   `path_attr.go`
*   `referenceable.go` (likely an interface)
*   `remove_target.go`
*   `resource_mode.go` (likely an enum)

Starting with `count_attr.go`.
