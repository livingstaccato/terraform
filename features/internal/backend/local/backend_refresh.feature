# Metadata:
# Covers: internal/backend/local/backend_refresh_test.go
# TestFunctions:
# - TestLocal_refresh
# - TestLocal_refreshInput
# - TestLocal_refreshValidate
# - TestLocal_refreshValidateProviderConfigured
# - TestLocal_refresh_context_error
# - TestLocal_refreshEmptyState

Feature: Local Backend Refresh Operation
  This feature describes the behavior of the 'refresh' operation when using the local backend,
  covering state updates, provider interactions, input handling, validation, and error scenarios.

  Background:
    Given a local backend is initialized for testing
    And a mock "test" provider is configured with a schema for "test_instance" (id string, ami string)
    And the configuration in "testdata/refresh" defines "test_instance.foo"

  Scenario: Basic Refresh Operation
    Given an initial state where "test_instance.foo" has id "bar"
    And the mock "test" provider's ReadResource will return new state with id "yes" for "test_instance.foo"
    When a Terraform refresh operation is run
    Then the operation should be successful
    And the provider's ReadResource method should have been called for "test_instance.foo"
    And the final state for "test_instance.foo" should have id "yes"
    And the backend state lock should be released

  Scenario: Refresh Operation Requiring Provider Configuration Input
    Given an initial state where "test_instance.foo" has id "bar"
    And the provider "test" requires an optional string attribute "value" for its configuration
    And the mock "test" provider's ReadResource will return new state with id "yes" for "test_instance.foo"
    And the UI is mocked to provide "bar" when prompted for "var.value" (or provider config value)
    And the provider's Configure method will expect its "value" attribute to be "bar"
    And the configuration in "testdata/refresh-var-unset" (implies provider config needs input)
    When a Terraform refresh operation is run with input enabled
    Then the operation should be successful
    And the provider's ReadResource method should have been called
    And the provider's Configure method should have been called successfully with the input value
    And the final state for "test_instance.foo" should have id "yes"

  Scenario: Refresh Operation with Validation Enabled
    Given an initial state where "test_instance.foo" has id "bar"
    And the mock "test" provider's ReadResource will return new state with id "yes" for "test_instance.foo"
    When a Terraform refresh operation is run with validation enabled
    Then the operation should be successful
    And the final state for "test_instance.foo" should have id "yes"
      # Note: Specific validation actions are not detailed here, only that refresh completes.

  Scenario: Refresh Operation with Validation Ensuring Provider Config Validation is Called
    Given an initial state where "test_instance.foo" has id "bar"
    And the mock "test" provider's ReadResource will return new state with id "yes" for "test_instance.foo"
    And the configuration in "testdata/refresh-provider-config" (has provider config block)
    When a Terraform refresh operation is run with validation enabled
    Then the operation should be successful
    And the provider's ValidateProviderConfig method should have been called
    And the final state for "test_instance.foo" should have id "yes"

  Scenario: Refresh Operation with Context Initialization Error
    Given an initial state exists
    And the configuration in "testdata/apply" # Using a generic config for this context error test
    And Terraform context initialization is configured to fail
    When a Terraform refresh operation is run
    Then the operation should fail
    And the backend state lock should be released

  Scenario: Refresh Operation with Empty Initial State
    Given the initial state is empty
    And the mock "test" provider's ReadResource will return new state with id "yes" for "test_instance.foo"
    When a Terraform refresh operation is run
    Then the operation should be successful # Refresh itself doesn't fail, but might produce warnings
    And a warning diagnostic should be produced containing "Empty or non-existent state"
    And the backend state lock should be released
      # Note: The state would still be updated if the provider found resources.

```

Notes for this Gherkin:
*   The `Background` sets up common elements.
*   Provider interactions (like `ReadResourceResponse`) are described in terms of their outcomes.
*   State verification is simplified to checking specific attributes.
*   The "Refresh Operation Requiring Provider Configuration Input" scenario is a bit complex due to the interaction of UI input and provider configuration. The Gherkin tries to capture the essence.
*   The "Context Initialization Error" scenario is generic about how the context fails, as the Go test notes this specific failure mechanism might change.

This covers the core scenarios from `backend_refresh_test.go`.

Next, I'll process `internal/backend/local/backend_test.go`.
