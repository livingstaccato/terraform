# Metadata:
#   Covers: internal/plugin6/grpc_provider_test.go
#   Tests:
#     - TestGRPCProvider_ReadDataSource
#     - TestGRPCProvider_ReadDataSourceJSON

Feature: ReadDataSource RPC
  As a Terraform plugin,
  I need to respond to ReadDataSource requests
  So that Terraform core can fetch data from external systems based on user configuration.

  Background:
    Given a configured tfplugin6 gRPC provider server
    And the provider defines a data source type "my_data_lookup"
    And its schema includes config attribute "query_input" (string) and computed attribute "result_output" (string)

  Scenario: Successfully read a data source and return its state (msgpack)
    Given a ReadDataSource request for "my_data_lookup" with config `{"query_input": "search_term_1"}`
    And the provider fetches data resulting in state `{"query_input": "search_term_1", "result_output": "found_value_1"}`
    And the provider will return the state encoded in msgpack
    When the ReadDataSource RPC is called
    Then the response should contain the state as DynamicValue (msgpack) reflecting `{"query_input": "search_term_1", "result_output": "found_value_1"}`
    And the response should not contain any error diagnostics

  Scenario: Successfully read a data source and return its state (JSON)
    Given a ReadDataSource request for "my_data_lookup" with config `{"query_input": "search_term_2"}`
    And the provider fetches data resulting in state `{"query_input": "search_term_2", "result_output": "found_value_2"}`
    And the provider will return the state encoded in JSON
    When the ReadDataSource RPC is called
    Then the response should contain the state as DynamicValue (JSON) reflecting `{"query_input": "search_term_2", "result_output": "found_value_2"}`
    And the response should not contain any error diagnostics

  Scenario: Read data source results in no data found (returns null for computed attributes or error)
    Given a ReadDataSource request for "my_data_lookup" with config `{"query_input": "non_existent_term"}`
    And the provider search finds no matching data for "non_existent_term"
    When the ReadDataSource RPC is called
    Then the response's state might have `result_output` as null `{"query_input": "non_existent_term", "result_output": null}`
    And the response should not contain error diagnostics if "not found" is a valid outcome (e.g. data source can return nulls)
    Alternatively:
    Then the response may contain an error diagnostic stating "No data found for query_input 'non_existent_term'" if "not found" is an error for this data source
    And the state in the response might be null or incomplete.

  Scenario: Read operation is deferred by the provider
    Given a ReadDataSource request for "my_data_lookup" with config `{"query_input": "defer_term"}`
    And the provider needs to defer the read (e.g., provider config has unknown values needed for the lookup)
    And the provider will return a deferred response with reason PROVIDER_CONFIG_UNKNOWN
    When the ReadDataSource RPC is called
    Then the response should indicate the operation is deferred
    And the deferred reason should be PROVIDER_CONFIG_UNKNOWN
    And the response's state might be null or partially populated with knowns from config
    And the response should not contain error diagnostics unless deferral itself is an error

  Scenario: Read data source encounters an API error (e.g., permission denied, service unavailable)
    Given a ReadDataSource request for "my_data_lookup" with config `{"query_input": "error_term"}`
    And fetching data for "error_term" fails due to an external API error
    When the ReadDataSource RPC is called
    Then the response should contain an error diagnostic explaining the API failure
    And the state in the response might be null

  Scenario: Handle gRPC error during ReadDataSource
    Given the provider's ReadDataSource RPC will return a gRPC error
    When a ReadDataSource request is made
    Then the overall operation should result in an error diagnostic reflecting the gRPC error

  Scenario: Read data source for an unknown data source type_name
    Given a ReadDataSource request is made for an unknown type "unknown_data_source" with some config
    When the ReadDataSource RPC is called
    Then the response should contain an error diagnostic indicating "unknown_data_source" is not a valid type

  Scenario: ReadDataSource request includes provider_meta
    Given a ReadDataSource request for "my_data_lookup" with config `{"query_input": "meta_term"}`
    And the provider requires provider_meta data for API calls (e.g., `{"auth_token": "token"}`)
    When a ReadDataSource request is made including this provider_meta
    Then the provider should use the provider_meta for its operations
    And the read should succeed if the meta and query are valid, returning the fetched state.

  Scenario: ReadDataSource request includes client capabilities
    Given a ReadDataSource request for "my_data_lookup" with config `{"query_input": "caps_term"}`
    And the request includes client capabilities (e.g. `deferral_allowed = true`)
    When a ReadDataSource request is made
    Then the provider should acknowledge these client capabilities
    And if deferral is needed and allowed, a deferred response is permissible.
    And the read should otherwise proceed normally.

  Scenario: Diagnostic message from data source read includes a specific attribute path
    # Usually, data source errors are general, but a complex config might have per-attribute issues.
    Given a "my_data_lookup" config `{"query_input": "complex_query", "filter_param": 123}` (where filter_param should be string)
    And validation within ReadDataSource (if not caught by ValidateDataResourceConfig) finds this type error
    When a ReadDataSource request is made
    Then the response should contain an error diagnostic
    And that diagnostic's attribute_path should point to "filter_param".

  Scenario: Data source config is empty, and all config attributes are optional
    Given "my_data_lookup" schema has only optional config attributes (e.g. "optional_query")
    And a ReadDataSource request is made for "my_data_lookup" with empty config `{}`
    And the provider can fetch default data or operate meaningfully with no specific config
    Resulting in state `{"optional_query": null, "result_output": "default_data"}`
    When the ReadDataSource RPC is called
    Then the response state should reflect `{"optional_query": null, "result_output": "default_data"}`
    And no error diagnostics should be present.

  Scenario: ReadDataSource when client does not allow deferral
    Given a ReadDataSource request for "my_data_lookup"
    And the request includes client capabilities with `deferral_allowed = false`
    And the provider logic would normally defer this read operation
    When a ReadDataSource request is made
    Then the provider should not return a deferred response
    And the provider should attempt to complete the read, or return an error if it cannot proceed without deferral.

  Scenario: ReadDataSource with config containing sensitive values
    Given "my_data_lookup" schema has a sensitive config attribute "api_key_input"
    And a ReadDataSource request is made with config `{"api_key_input": "secret_key", "query_input": "secure_term"}`
    And the provider uses "api_key_input" to authenticate and fetches data `{"result_output": "data_for_secret_key"}`
    When the ReadDataSource RPC is called
    Then the response state should include `{"api_key_input": "secret_key", "query_input": "secure_term", "result_output": "data_for_secret_key"}`
    And Terraform Core handles the sensitivity of "api_key_input" in the state.
    # Provider just populates the state based on its schema.

  Scenario: ReadDataSource returns computed values that were not in config
    Given a ReadDataSource request for "my_data_lookup" with config `{"query_input": "term_for_computed"}`
    And the provider computes additional attributes like "timestamp" (string, computed) and "version" (number, computed)
    Resulting in state `{"query_input": "term_for_computed", "result_output": "val", "timestamp": "2023-01-01T10:00:00Z", "version": 3}`
    When the ReadDataSource RPC is called
    Then the response state should reflect all attributes, including new computed ones.

  Scenario: ReadDataSource where config itself has unknown values (e.g. depends on a resource not yet created)
    # If config has unknowns, ReadDataSource might be deferred or might attempt to proceed if possible.
    Given a ReadDataSource request for "my_data_lookup" with config `{"query_input": (unknown)}`
    When the ReadDataSource RPC is called
    Then the provider might return a deferred response if it cannot proceed with an unknown `query_input`
    Or, if it can make a "best effort" or if the unknown doesn't block the call, it might proceed or error.
    # A common outcome is deferral if client_capabilities.deferral_allowed is true.
    # If deferral not allowed, an error "query_input must be known" is likely.
    And if deferred, the reason could be RESOURCE_CONFIG_UNKNOWN.
    And if errored, an appropriate diagnostic should be returned.
