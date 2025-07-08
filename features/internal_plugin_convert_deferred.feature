# Source Go File: internal/plugin/convert/deferred.go
# Source Go Test: internal/plugin/convert/deferred_test.go

Feature: Deferred Reason Conversion from Protobuf
  This feature describes how a tfplugin5.Deferred message from Protobuf,
  which indicates why a provider action might be deferred, is converted
  into Terraform's internal providers.DeferredReason type.
  This conversion does not directly involve complex cty.Value manipulations
  but is part of the plugin communication protocol where cty values flow.

  Background:
    Given the plugin deferred reason conversion context

  Scenario Outline: Converting proto.Deferred_Reason to providers.DeferredReason
    Given a proto.Deferred message with Reason set to <ProtoReason>
    When ProtoToDeferred is called with this message
    Then the resulting providers.Deferred object should have its Reason field set to <ExpectedProvidersReason>

    Examples:
      | ProtoReason                      | ExpectedProvidersReason           |
      | UNKNOWN                          | DeferredReasonInvalid             |
      | RESOURCE_CONFIG_UNKNOWN          | DeferredReasonResourceConfigUnknown |
      | PROVIDER_CONFIG_UNKNOWN          | DeferredReasonProviderConfigUnknown |
      | ABSENT_PREREQ                    | DeferredReasonAbsentPrereq        |
      | 99 # Some undefined proto reason | DeferredReasonInvalid             | # Default case for undefined proto reasons

  Scenario: Converting a nil proto.Deferred message
    Given a nil proto.Deferred message
    When ProtoToDeferred is called with this nil message
    Then the result should be nil (a nil *providers.Deferred pointer)

  # Note: The primary cty aspect here is that this conversion is part of the overall
  # plugin framework that handles cty.Value for resource data, configurations, etc.
  # This specific conversion is about control flow reasons rather than data values.
  # The BDD focuses on the direct input/output of the conversion function.
  # Helper step definitions will need to map string representations of enum values
  # to their actual Go/proto enum counterparts.
