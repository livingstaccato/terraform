# Source Go File: internal/backend/init/deprecate.go
# Source Go Test: internal/backend/init/deprecate_test.go

Feature: Deprecated Backend Handling
  This feature describes how Terraform handles backends that have been marked
  as deprecated. When such a backend's configuration is prepared, a diagnostic
  warning should be issued.

  Background:
    Given the backend initialization system

  Scenario: Preparing configuration for a deprecated backend
    Given an existing backend (e.g., an in-memory backend)
    And this backend is wrapped using `deprecateBackend` with the message "This backend is deprecated and will be removed"
    When PrepareConfig is called on the deprecated backend wrapper (e.g., with an empty cty.ObjectVal)
    Then exactly one diagnostic should be produced
    And this diagnostic should have Severity WARNING
    And its Summary should be "This backend is deprecated and will be removed"

  # Note:
  # - The `deprecateBackend` function takes an existing backend (which implements the backend.Backend interface)
  #   and returns a new backend that wraps the original, adding deprecation warnings.
  # - The cty.Value passed to PrepareConfig (e.g., cty.EmptyObjectVal) is the backend configuration.
  #   The actual configuration content isn't central to this test, only that PrepareConfig is called.
  # - The core cty aspect is that PrepareConfig receives and processes a cty.Value for the configuration,
  #   and the test verifies diagnostics related to this process for deprecated backends.
