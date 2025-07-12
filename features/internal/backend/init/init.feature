# Metadata:
# Covers: internal/backend/init/init_test.go, internal/backend/init/init.go (Set function)
# TestFunctions:
# - TestInit_backend
# Additional behavior for Set() derived from source code analysis.

Feature: Backend Initialization, Retrieval, and Dynamic Management
  This feature describes how Terraform initializes, retrieves, and dynamically manages
  backend implementations by their registered names.

  Background:
    Given the backend system has been initialized

  Scenario Outline: Retrieving Registered Backend Implementations
    When I request the backend implementation for name "<BackendName>"
    Then a backend factory should be returned
    And the factory should produce a backend instance of type "<ExpectedGoType>"

    Examples:
      | BackendName | ExpectedGoType        |
      | local       | *local.Local          |
      | remote      | *remote.Remote        |
      | azurerm     | *azure.Backend        |
      | consul      | *consul.Backend       |
      | cos         | *cos.Backend          |
      | gcs         | *gcs.Backend          |
      | inmem       | *inmem.Backend        |
      | pg          | *pg.Backend           |
      | s3          | *s3.Backend           |
      # Note: The Go test specifically checks the types listed above.
      # Other backends like http, kubernetes, oci, cloud are also initialized by the Init() function.

  Scenario: Dynamically Setting and Retrieving a Custom Backend
    Given the backend system has been initialized
    And a custom backend factory "my_custom_backend_factory" is defined to produce a "*custom.Backend" type
    When I set the backend named "custom" using "my_custom_backend_factory"
    And I request the backend implementation for name "custom"
    Then a backend factory should be returned
    And the factory should produce a backend instance of type "*custom.Backend"

  Scenario: Overwriting an Existing Backend with a Custom One
    Given the backend system has been initialized
    And a custom backend factory "my_override_factory" is defined to produce a "*override.Backend" type
    When I set the backend named "local" using "my_override_factory" # Overwriting "local"
    And I request the backend implementation for name "local"
    Then a backend factory should be returned
    And the factory should produce a backend instance of type "*override.Backend"

  Scenario: Removing a Backend
    Given the backend system has been initialized
    And the backend named "inmem" exists and can be retrieved
    When I remove the backend named "inmem" by setting its factory to nil
    And I request the backend implementation for name "inmem"
    Then no backend factory should be returned (it should be nil)
