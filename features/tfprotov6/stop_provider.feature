# Metadata:
#   Covers: internal/plugin6/grpc_provider_test.go
#   Tests:
#     - TestGRPCProvider_Stop (which tests StopProvider RPC)

Feature: StopProvider RPC
  As a Terraform plugin,
  I need to respond to StopProvider requests
  So that Terraform core can signal me to gracefully shut down and release any resources.

  Background:
    Given a configured tfplugin6 gRPC provider server
    And the provider has been initialized (e.g., via ConfigureProvider)

  Scenario: Successfully stop the provider
    When the StopProvider RPC is called
    Then the provider should perform any necessary cleanup operations
    And the response should not contain an error message (empty or null Error string)
    # The Go test `TestGRPCProvider_Stop` expects no error from p.Stop() which calls the RPC.

  Scenario: StopProvider is called on a provider that was not configured/initialized
    # The StopProvider RPC might be called even if ConfigureProvider failed or was never called.
    # The provider should handle this gracefully.
    Given a tfplugin6 gRPC provider server that has not been successfully configured
    When the StopProvider RPC is called
    Then the provider should attempt to stop gracefully, without errors due to lack of configuration
    And the response should not contain an error message

  Scenario: Provider encounters an issue during shutdown and reports an error
    Given the provider is performing a complex shutdown task (e.g., flushing a data queue)
    And an error occurs during this shutdown task
    When the StopProvider RPC is called
    Then the provider attempts its shutdown procedure
    And the response should contain an Error string detailing the shutdown issue
    # Example: "Failed to flush resource cache: timeout"

  Scenario: Handle gRPC error during StopProvider call itself
    # This is distinct from the provider *reporting* an error in its response.
    # This is about the RPC call failing.
    Given the provider's StopProvider RPC endpoint will return a fundamental gRPC error (e.g., server no longer reachable)
    When the StopProvider RPC is called
    Then the client attempting to call StopProvider should observe a gRPC-level error
    # The BDD step would focus on the client's observation of this failure.

  Scenario: StopProvider is called multiple times
    # While not ideal, core might call StopProvider multiple times in some edge cases or due to client logic.
    Given the StopProvider RPC has already been called once and the provider is shutting down or stopped
    When the StopProvider RPC is called again
    Then the provider should handle the subsequent call gracefully
    And the response should not contain an error message (or reflect its current stopped/stopping state without new errors)
    # For example, it might return an empty error or the same error if the first stop also had issues.
    # The key is that it shouldn't crash or enter an inconsistent state.

  Scenario: StopProvider request parameters (currently none)
    # The StopProvider.Request message is currently empty.
    # This scenario is a placeholder for if it ever gets parameters.
    Given a StopProvider request is made (with any future parameters)
    When the StopProvider RPC is called
    Then the provider should process the request according to its definition
    And respond appropriately.
    # Currently, this means just acknowledging the stop signal.
