# Source Go File: internal/plugin/convert/diagnostics.go
# Source Go Test: internal/plugin/convert/diagnostics_test.go

Feature: Diagnostic Conversion between tfdiags and tfplugin5 Protobuf
  This feature describes how Terraform's internal diagnostics (tfdiags.Diagnostic)
  are converted to and from the tfplugin5 Protobuf format (proto.Diagnostic),
  particularly focusing on the representation of cty.Path for attribute-related
  diagnostics.

  Background:
    Given the plugin diagnostic conversion context

  Scenario Outline: Converting tfdiags.Diagnostic with cty.Path to proto.Diagnostic
    Given a tfdiags.Diagnostic with Severity <Severity>, Summary "<Summary>", Detail "<Detail>"
    And the diagnostic is associated with cty.Path <CtyPathStepsJSON>
      # CtyPathStepsJSON is a JSON array of steps, e.g.,
      # '[{"type":"GetAttr","name":"attr"}, {"type":"Index","key_type":"String","key_value":"key"}]'
    When this diagnostic is converted to proto.Diagnostic using internal conversion logic
      # (This is implicitly tested by creating tfdiags and then checking its proto representation if a direct function isn't public)
      # Or, more directly, by testing PathToAttributePath if that's the core cty.Path related part.
    Then the resulting proto.Diagnostic should have Severity <ProtoSeverity>
    And its Summary should be "<Summary>"
    And its Detail should be "<Detail>"
    And its Attribute field (a proto.AttributePath) should represent <ExpectedProtoPathStepsJSON>
      # ExpectedProtoPathStepsJSON is a JSON array of proto.AttributePath_Step
      # e.g., '[{"selector_type":"AttributeName","value":"attr"}, {"selector_type":"ElementKeyString","value":"key"}]'

    Examples:
      | Severity | Summary        | Detail         | CtyPathStepsJSON                                                                               | ProtoSeverity | ExpectedProtoPathStepsJSON                                                                                                   |
      | ERROR    | "Attr Error"   | "Detail here"  | "[{\"type\":\"GetAttr\",\"name\":\"resource_name\"},{\"type\":\"GetAttr\",\"name\":\"attribute\"}]" | ERROR         | "[{\"selector_type\":\"AttributeName\",\"value\":\"resource_name\"},{\"selector_type\":\"AttributeName\",\"value\":\"attribute\"}]" |
      | WARNING  | "Index Warning"| "More detail"  | "[{\"type\":\"GetAttr\",\"name\":\"my_list\"},{\"type\":\"Index\",\"key_type\":\"Number\",\"key_value\":0}]" | WARNING       | "[{\"selector_type\":\"AttributeName\",\"value\":\"my_list\"},{\"selector_type\":\"ElementKeyInt\",\"value\":0}]"           |
      | ERROR    | "Map Key Error"| "Path to map"  | "[{\"type\":\"GetAttr\",\"name\":\"my_map\"},{\"type\":\"Index\",\"key_type\":\"String\",\"key_value\":\"map_key\"}]" | ERROR         | "[{\"selector_type\":\"AttributeName\",\"value\":\"my_map\"},{\"selector_type\":\"ElementKeyString\",\"value\":\"map_key\"}]" |
      | ERROR    | "No Path"      | "No attribute" | "[]"                                                                                           | ERROR         | "null"                                                                                                                       | # Empty path means proto Attribute field is nil

  Scenario Outline: Converting proto.Diagnostic with AttributePath to tfdiags.Diagnostic
    Given a proto.Diagnostic with Severity <ProtoSeverity>, Summary "<Summary>", Detail "<Detail>"
    And its Attribute field (a proto.AttributePath) represents <ProtoPathStepsJSON>
    When ProtoToDiagnostics is called with a list containing this proto.Diagnostic
    Then the first resulting tfdiags.Diagnostic should have Severity <Severity>
    And its Summary should be "<Summary>"
    And its Detail should be "<Detail>"
    And if <ProtoPathStepsJSON> is not "null" or empty, GetAttribute on the diagnostic should return a cty.Path equivalent to <ExpectedCtyPathStepsJSON>
    And if <ProtoPathStepsJSON> is "null" or empty, GetAttribute on the diagnostic should return an empty cty.Path or indicate a whole body diagnostic

    Examples:
      | ProtoSeverity | Summary        | Detail         | ProtoPathStepsJSON                                                                                                   | Severity | ExpectedCtyPathStepsJSON                                                                               |
      | ERROR         | "Attr Error"   | "Detail here"  | "[{\"selector_type\":\"AttributeName\",\"value\":\"resource_name\"},{\"selector_type\":\"AttributeName\",\"value\":\"attribute\"}]" | ERROR    | "[{\"type\":\"GetAttr\",\"name\":\"resource_name\"},{\"type\":\"GetAttr\",\"name\":\"attribute\"}]" |
      | WARNING       | "Index Warning"| "More detail"  | "[{\"selector_type\":\"AttributeName\",\"value\":\"my_list\"},{\"selector_type\":\"ElementKeyInt\",\"value\":0}]"           | WARNING  | "[{\"type\":\"GetAttr\",\"name\":\"my_list\"},{\"type\":\"Index\",\"key_type\":\"Number\",\"key_value\":0}]" |
      | ERROR         | "Map Key Error"| "Path to map"  | "[{\"selector_type\":\"AttributeName\",\"value\":\"my_map\"},{\"selector_type\":\"ElementKeyString\",\"value\":\"map_key\"}]" | ERROR    | "[{\"type\":\"GetAttr\",\"name\":\"my_map\"},{\"type\":\"Index\",\"key_type\":\"String\",\"key_value\":\"map_key\"}]" |
      | ERROR         | "No Path"      | "No attribute" | "null"                                                                                                               | ERROR    | "[]"                                                                                                   | # Null AttributePath results in non-attribute tfdiag
      | ERROR         | "Empty Steps"  | "Empty path"   | "[]"                                                                                                                 | ERROR    | "[]"                                                                                                   | # Empty Steps list results in non-attribute tfdiag

  Scenario: Converting simple warnings and errors to proto.Diagnostic
    Given a list of warning strings: ["warning 1", "warning 2"]
    And a list of error objects: [Error("error 1"), Error("error 2")]
      # Error() implies Go errors created with errors.New() or fmt.Errorf()
    When WarnsAndErrsToProto is called with these warnings and errors
    Then the resulting list of proto.Diagnostic should have 4 items
    And the first two items should have Severity WARNING and Summaries "warning 1", "warning 2" respectively
    And the next two items should have Severity ERROR and Summaries "error 1", "error 2" respectively

  Scenario: Converting cty.PathError to proto.Diagnostic
    Given a cty.PathError with path <CtyPathStepsJSON> and error message "<ErrorMessage>"
    When AppendProtoDiag is called with this cty.PathError
    Then the resulting proto.Diagnostic should have Severity ERROR
    And its Summary should be "<ErrorMessage>"
    And its Attribute field should represent the cty.Path <CtyPathStepsJSON>

    Examples:
      | CtyPathStepsJSON                                                               | ErrorMessage            |
      | "[{\"type\":\"GetAttr\",\"name\":\"some_attr\"}]"                               | "Error at some_attr"    |
      | "[{\"type\":\"GetAttr\",\"name\":\"list\"},{\"type\":\"Index\",\"key_value\":0}]" | "Error at list[0]"      |


  # Helper step definitions will be needed for:
  # - Parsing <CtyPathStepsJSON> and <ExpectedCtyPathStepsJSON> into cty.Path objects.
  # - Parsing <ProtoPathStepsJSON> and <ExpectedProtoPathStepsJSON> into proto.AttributePath objects.
  # - Creating tfdiags.Diagnostic and proto.Diagnostic instances based on the provided details.
  # - Comparing tfdiags.Severity with proto.Diagnostic_Severity.
  # - Comparing cty.Path objects for equivalence.
  # - Note: cty.IndexStep keys (Number or String) need to be correctly translated to/from proto selector types (ElementKeyInt, ElementKeyString).
  # - An empty or nil proto.AttributePath should result in a tfdiags.Diagnostic that is not an AttributeValue diagnostic (e.g., WholeContainingBody).
  # - The test `TestProtoDiagnostics_emptyAttributePath` shows that an AttributePath with empty steps results in a whole body diagnostic.
  # - `WarnsAndErrsToProto` and `AppendProtoDiag` are direct functions to test.
  # - `ProtoToDiagnostics` and `PathToAttributePath`/`AttributePathToPath` are the core conversion logic.
