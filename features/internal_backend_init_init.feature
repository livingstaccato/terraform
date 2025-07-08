# Source Go File: internal/backend/init/init.go
# Source Go Test: internal/backend/init/init_test.go

Feature: Backend Initialization and Retrieval
  This feature describes the initialization of available backend types in Terraform
  and the ability to retrieve a specific backend factory by its name.

  Background:
    Given the backend initialization system has been invoked via Init(nil)

  Scenario Outline: Retrieving a registered backend factory by name
    Given the backend system has been initialized
    When the Backend function is called with name "<BackendName>"
    Then a non-nil backend factory function should be returned
    And calling this factory function should produce a backend instance of Go type "<ExpectedGoType>"

    Examples:
      | BackendName | ExpectedGoType      |
      | "local"     | "*local.Local"      |
      | "remote"    | "*remote.Remote"    |
      | "azurerm"   | "*azure.Backend"    |
      | "consul"    | "*consul.Backend"   |
      | "cos"       | "*cos.Backend"      |
      | "gcs"       | "*gcs.Backend"      |
      | "inmem"     | "*inmem.Backend"    |
      | "pg"        | "*pg.Backend"       |
      | "s3"        | "*s3.Backend"       |
      # Note: HTTP backend is not directly in the `backends` map in init.go, it's handled differently.

  Scenario: Retrieving a non-existent backend factory
    Given the backend system has been initialized
    When the Backend function is called with name "non_existent_backend"
    Then a nil backend factory function should be returned

  # Note:
  # - The `Init(nil)` call populates an internal map of backend factories.
  # - The `Backend(name)` function retrieves a factory from this map.
  # - The cty aspects are indirect: backends handle state, which is stored and
  #   managed often involving cty.Value representations, although this specific
  #   functionality is about the factory mechanism, not the state data itself.
  # - ExpectedGoType refers to the string representation of the Go type of the
  #   instance returned by the factory, as checked by `reflect.TypeOf(f()).String()`.
  # - The test for "http" backend is not included here as it's not in the `backends` map
  #   in `init.go` and is typically handled via a different mechanism (remote state data source).
  #   The Go test `TestInit_backend` also doesn't explicitly check for "http".
