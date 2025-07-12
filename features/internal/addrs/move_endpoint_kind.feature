# Metadata:
# Covers: internal/addrs/move_endpoint_kind.go (specifically absMoveableEndpointKind logic)
# Behavior derived from source code analysis.

Feature: Move Endpoint Kind Determination
  This feature describes how Terraform determines the kind (Module or Resource)
  of an absolute moveable address, which is used in processing 'moved' blocks.

  Scenario Outline: Determining the Kind of an Absolute Moveable Address
    Given an absolute moveable address "<AddressString>" of type <AddressType>
    When its move endpoint kind is determined
    Then the kind should be <ExpectedKind>

    Examples:
      | AddressString                     | AddressType           | ExpectedKind           |
      | module.foo                        | ModuleInstance        | MoveEndpointModule     |
      | module.foo[0].call.bar            | AbsModuleCall         | MoveEndpointModule     | # AbsModuleCall is for module call *instance*
      | aws_instance.web                  | AbsResource           | MoveEndpointResource   |
      | data.template_file.example["key"] | AbsResourceInstance   | MoveEndpointResource   |
      | module.app.aws_instance.api       | AbsResource           | MoveEndpointResource   |
      | module.app.module.child           | ModuleInstance        | MoveEndpointModule     |
