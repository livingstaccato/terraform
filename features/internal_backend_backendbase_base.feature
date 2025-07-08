# Source Go File: internal/backend/backendbase/base.go
# Source Go Test: internal/backend/backendbase/base_test.go

Feature: Backend Base Configuration Preparation
  This feature describes how the `backendbase.Base` type prepares and validates
  backend configuration using a configschema.Block. This involves coercing input
  cty.Value to the schema, handling defaults, and issuing diagnostics for errors
  or deprecated arguments.

  Background:
    Given a backendbase.Base initialized with a specific configschema.Block

  Scenario: Preparing valid backend configuration
    Given the Base schema defines an optional string attribute "foo"
    And an input configuration cty.ObjectVal with "foo" = cty.StringVal("bar")
    When PrepareConfig is called with this input configuration
    Then the resulting prepared cty.Value should be an object with "foo" = cty.StringVal("bar")
    And no diagnostics should be produced

  Scenario: Coercion error during configuration preparation
    Given the Base schema defines an optional string attribute "foo"
    And an input configuration cty.ObjectVal with "foo" = cty.MapValEmpty(cty.String) (incorrect type)
    When PrepareConfig is called with this input configuration
    Then diagnostics should be produced with an error summary "Invalid backend configuration"
    And the error detail should contain ".foo: string required"

  Scenario: Handling deprecated top-level argument
    Given the Base schema defines an optional string attribute "deprecated_attr" marked as deprecated
    And an input configuration cty.ObjectVal with "deprecated_attr" = cty.StringVal("value")
    When PrepareConfig is called with this input configuration
    Then diagnostics should be produced with a warning summary "Deprecated provider argument"
    And the warning detail should contain ".deprecated_attr is deprecated"

  Scenario: Handling deprecated nested argument
    Given the Base schema defines a list block "nested_block"
    And "nested_block" has an optional string attribute "deprecated_nested_attr" marked as deprecated
    And an input configuration cty.ObjectVal with "nested_block" = List[Object{"deprecated_nested_attr": "value"}]
    When PrepareConfig is called with this input configuration
    Then diagnostics should be produced with a warning summary "Deprecated provider argument"
    And the warning detail should contain ".nested_block[0].deprecated_nested_attr is deprecated"

  Scenario: Handling null input configuration for a required attribute
    Given the Base schema defines a required string attribute "foo"
    And SDKLikeDefaults provides a fallback "fallback_value" for "foo" (though this shouldn't apply for required on null)
    And the input configuration is cty.NullVal(cty.Object({"foo": cty.String}))
    When PrepareConfig is called with this null input configuration
    Then diagnostics should be produced with an error summary "Invalid backend configuration"
    And the error detail should contain "attribute \"foo\" is required"

  Scenario: Successfully preparing configuration with no deprecated arguments used
    Given the Base schema defines:
      - Optional string attribute "not_deprecated"
      - Optional, deprecated string attribute "deprecated_attr"
      - Optional list block "nested_block" with a deprecated attribute "deprecated_nested_attr"
    And an input configuration cty.ObjectVal with "not_deprecated" = cty.StringVal("hello")
    When PrepareConfig is called with this input configuration
    Then the resulting prepared cty.Value should be an object with:
      - "not_deprecated" = cty.StringVal("hello")
      - "deprecated_attr" = cty.NullVal(cty.String)
      - "nested_block" = cty.ListValEmpty(cty.Object({"deprecated_nested_attr": cty.String}))
    And no diagnostics should be produced

  # Note:
  # - The cty aspects are central here: input is cty.Value, schema is configschema.Block (which uses cty.Type),
  #   and output is a prepared cty.Value along with diagnostics.
  # - Step definitions will need to construct configschema.Block and cty.Value instances based on descriptions.
  # - Diagnostics checking will involve verifying severity, summary, and detail, and potentially subject range
  #   if a mock HCL body is used (as in the Go tests).
  # - SDKLikeDefaults interaction is also relevant for how defaults are applied or not.
  # - The test `TestBase_nullCrash` specifically checks that providing a null object value (not a null pointer to Base)
  #   for a schema that requires attributes still produces the correct "attribute required" error rather than crashing.
  # - The `InConfigBody` method is used in Go tests to associate diagnostics with source ranges from a mock body.
  #   For BDD, we can focus on the content of the diagnostics unless specific source range testing is needed.
