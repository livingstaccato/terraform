# Source Go File: internal/backend/local/backend_refresh.go
# Source Go Test: internal/backend/local/backend_refresh_test.go

Feature: Local Backend Refresh Operation
  This feature describes the refresh operation for the local backend. It covers
  how the backend interacts with providers to update the state from the real
  infrastructure and handles various scenarios like input prompts and validation.
  Cty.Value is used for resource states, provider configurations, and schemas.

  Background:
    Given a local backend initialized for testing
    And a mock "test" provider configured for the backend with a defined schema for "test_instance"

  Scenario: Basic refresh operation updating a resource
    Given an existing state file where "test_instance.foo" has ID "bar"
    And the "test" provider's ReadResourceFn is configured to return a new state:
      cty.ObjectVal({"id": "yes"}) for "test_instance.foo"
    And a refresh operation is prepared for configuration in "./testdata/refresh"
    When the backend performs the refresh operation
    Then the provider's ReadResourceFn should have been called
    And the final state should contain "test_instance.foo" with attributes {"id":"yes"}
    And the backend state should be unlocked after the run

  Scenario: Refresh operation requiring user input for a provider configuration
    Given an existing state file
    And the "test" provider schema requires a string attribute "value" for its configuration
    And the "test" provider's ConfigureProviderFn will check if "value" is "bar"
    And the backend's UIInput is mocked to return "bar" when prompted
    And a refresh operation is prepared for configuration in "./testdata/refresh-var-unset" (which doesn't set the provider value)
    When the backend performs the refresh operation with input enabled
    Then the provider's ConfigureProviderFn should have been called successfully (with "value":"bar")
    And the provider's ReadResourceFn should have been called
    And the final state should be updated (e.g., "test_instance.foo" with ID "yes")

  Scenario: Refresh operation with validation enabled
    Given an existing state file
    And the "test" provider's ReadResourceFn is configured to return a new state
    And a refresh operation is prepared for configuration in "./testdata/refresh"
    And the backend's operation validation is enabled
    When the backend performs the refresh operation
    Then the final state should be updated
    # Implies that validation steps (if any specific to refresh) were also performed

  Scenario: Refresh operation with validation enabled and provider configuration
    Given an existing state file
    And the "test" provider schema includes provider configuration attributes
    And a refresh operation is prepared for configuration in "./testdata/refresh-provider-config" (which sets provider config)
    And the backend's operation validation is enabled
    When the backend performs the refresh operation
    Then the provider's ValidateProviderConfigFn should have been called
    And the final state should be updated

  Scenario: Refresh operation with a context error (e.g., invalid provider schema for context creation)
    Given an existing state file
    And the backend is configured to cause an error during Terraform Context creation (e.g., by omitting provider schema)
    And a refresh operation is prepared for configuration in "./testdata/apply" (or any valid config)
    When the backend performs the refresh operation
    Then the operation result should be OperationFailure
    And the backend state should be unlocked after the run

  Scenario: Refresh operation with an empty or non-existent state file
    Given an empty or non-existent state file
    And the "test" provider's ReadResourceFn is configured to return a new state
    And a refresh operation is prepared for configuration in "./testdata/refresh"
    When the backend performs the refresh operation
    Then a warning diagnostic should be produced with summary "Empty or non-existent state"
    And the backend state should be unlocked after the run

  # Note:
  # - cty.Value is used for:
  #   - Mock provider's ReadResourceResponse.NewState.
  #   - Initializing states.State with resource attributes.
  #   - Verifying resource attributes in the final states.State.
  #   - Provider configuration (cty.Value for ConfigureProviderFn).
  # - Schema definitions (refreshFixtureSchema) use cty.Type.
  # - testOperationRefresh sets up backendrun.Operation.
  # - testRefreshState() creates a sample states.State.
  # - This BDD focuses on the local backend's orchestration of the refresh graph and state updates.
  # - Provider interactions (ReadResourceFn, ConfigureProviderFn, ValidateProviderConfigFn) are key.
  # - State locking/unlocking is an important side effect.
