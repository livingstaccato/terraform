# Source Go File: internal/terraform/context_apply.go
# Source Go Test: internal/terraform/context_apply_test.go (and others like context_apply2_test.go, etc.)

Feature: Terraform Context Apply Operations
  This feature describes how the Terraform Context applies a plan, focusing on
  the handling of cty.Value for variables, resource states, and provider interactions.

  Background:
    Given a Terraform Context initialized with mock providers and configurations
    And a previously generated execution plan

  Scenario: Applying a basic plan with cty.Value conversions
    Given the plan involves creating a resource "test_resource.foo" with attributes {"config_attr": "config_value"}
    And the provider's ApplyResourceChangeFn will return a new state with {"id": "res-123", "computed_attr": "computed_value"}
    When the Context applies this plan
    Then the resulting state should contain "test_resource.foo"
    And its current object's attributes (decoded cty.Value) should include {"id": "res-123", "computed_attr": "computed_value", "config_attr": "config_value"}

  Scenario: Applying a plan with unknown values that become known
    Given the plan for "test_resource.unstable" has an attribute "random_id" as cty.UnknownVal(cty.String)
    And the provider's ApplyResourceChangeFn will resolve "random_id" to a known cty.StringVal like "uuid-xyz"
    When the Context applies this plan
    Then the resulting state for "test_resource.unstable" attribute "random_id" should be a known cty.StringVal "uuid-xyz"

  Scenario: Applying a plan with sensitive input variables
    Given the plan was created with a sensitive variable "var.api_key" = cty.StringVal("secret").Mark("sensitive")
    And this variable is used in a resource attribute "test_resource.app.api_token"
    When the Context applies this plan
    Then the resulting state for "test_resource.app.api_token" should be cty.StringVal("secret")
    And its AttrSensitivePaths should include the path to "api_token"

  Scenario: Applying a plan with ephemeral input variables set via ApplyOpts
    Given the plan indicates "var.ephemeral_token" is an apply-time variable
    And ApplyOpts provides "var.ephemeral_token" = cty.StringVal("temp-apply-token")
    And this variable is used in "test_resource.temp_res.token"
    When the Context applies this plan with these ApplyOpts
    Then the resulting state for "test_resource.temp_res.token" should be cty.StringVal("temp-apply-token")

  Scenario: Error when required apply-time variable is not provided
    Given the plan indicates "var.required_ephemeral" is an apply-time variable
    And ApplyOpts does not provide "var.required_ephemeral"
    When the Context attempts to apply this plan
    Then diagnostics should be produced with an error summary "No value for required variable" for "var.required_ephemeral"

  Scenario: Error when unexpected apply-time variable is provided for non-ephemeral var
    Given the plan does not mark "var.fixed_var" as an apply-time variable
    And ApplyOpts provides "var.fixed_var" = cty.StringVal("new_value")
    When the Context attempts to apply this plan
    Then diagnostics should be produced with an error summary "Unexpected new value for variable" for "var.fixed_var"

  Scenario: Provider returning inconsistent cty.Value during apply (value changed when it shouldn't)
    Given the plan for "test_resource.consistency" shows attribute "fixed_attr" as cty.StringVal("planned_value") with no change
    And the provider's ApplyResourceChangeFn for "test_resource.consistency" incorrectly returns a new state where "fixed_attr" is cty.StringVal("changed_value")
    When the Context applies this plan
    Then diagnostics should be produced with an error summary "Provider produced inconsistent result after apply"

  Scenario: Provider returning a new state that does not conform to schema
    Given the plan for "test_resource.schema_mismatch"
    And the provider's ApplyResourceChangeFn returns a cty.ObjectVal missing a required attribute defined in the schema
    When the Context applies this plan
    Then diagnostics should be produced indicating a schema conformance error for the returned state

  Scenario: Handling cty.NilVal from provider's ApplyResourceChangeFn (resource update fails, state retained)
    Given "test_resource.existing" is in the prior state with attributes {"attr": "old_value"}
    And the plan is to update "test_resource.existing"
    And the provider's ApplyResourceChangeFn returns an error and cty.NilVal for the new state
    When the Context applies this plan
    Then the resulting state for "test_resource.existing" should still contain the attributes {"attr": "old_value"}
    And its status might be tainted or reflect the failure, but the cty.Value itself is preserved

  Scenario: Handling CreateBeforeDestroy with cty.Value transformations
    Given "aws_instance.web" exists with {"id":"old_id", "require_new":"old_val"}
    And the plan is to replace "aws_instance.web" due to "require_new" changing to "new_val" (CreateBeforeDestroy=true)
    And the provider ApplyResourceChangeFn for create returns {"id":"new_id", "require_new":"new_val"}
    And the provider ApplyResourceChangeFn for delete succeeds
    When the Context applies this plan
    Then the final state for "aws_instance.web" should have attributes {"id":"new_id", "require_new":"new_val"}
    And the old instance object {"id":"old_id"} should be deposed and then removed

  Scenario: Propagating cty.Value marks (sensitive) from plan to state
    Given the plan for "test_resource.marked_res" has an attribute "sensitive_data" as cty.StringVal("secret").Mark("sensitive")
    When the Context applies this plan
    Then the resulting state for "test_resource.marked_res" attribute "sensitive_data" should be cty.StringVal("secret")
    And its AttrSensitivePaths should include the path to "sensitive_data"

  # Helper step definitions will be needed to:
  # - Set up mock providers with specific ApplyResourceChangeFn behaviors that return controlled cty.Values and diagnostics.
  # - Construct plans.Plan objects with specific cty.Values for VariableValues, resource changes (Before, After, AfterSensitivePaths).
  # - Define ApplyOpts with cty.Values for SetVariables.
  # - Verify the resulting states.State, checking specific resource instance attributes (cty.Value) and metadata like AttrSensitivePaths.
  # - Decode ResourceInstanceObjectSrc.AttrsJSON back to cty.Value for comparison.
  # - Check for specific tfdiags.Diagnostic messages.
  # - Use cty.ObjectVal, cty.StringVal, cty.NumberIntVal, cty.NullVal, cty.UnknownVal, .Mark() etc., to define cty values.
