# Metadata:
#   Covers: internal/plugin6/grpc_provider_test.go
#   Tests:
#     - TestGRPCProvider_openEphemeralResource
#     - TestGRPCProvider_renewEphemeralResource
#     - TestGRPCProvider_closeEphemeralResource
#   Also covers ValidateEphemeralResourceConfig RPC based on proto definition.

Feature: Ephemeral Resource Lifecycle RPCs
  As a Terraform plugin,
  I need to manage the lifecycle of ephemeral resources (Validate, Open, Renew, Close)
  So that Terraform core can use temporary, short-lived resources or sessions provided by the plugin.

  Background:
    Given a configured tfplugin6 gRPC provider server
    And the provider defines an ephemeral resource type "my_temp_session"
    And its schema includes config attribute "session_name" (string) and computed/result attribute "session_id" (string), "status" (string)
    And its OpenEphemeralResource operation can return private data for renewal/closure.

  Scenario: Successfully validate ephemeral resource configuration
    Given a ValidateEphemeralResourceConfig request for "my_temp_session" with config `{"session_name": "test_session"}`
    When the ValidateEphemeralResourceConfig RPC is called
    Then the response should not contain any error diagnostics.

  Scenario: Validate ephemeral resource configuration with errors
    Given the "my_temp_session" schema requires "session_name"
    And a ValidateEphemeralResourceConfig request for "my_temp_session" with config `{}` (missing session_name)
    When the ValidateEphemeralResourceConfig RPC is called
    Then the response should contain an error diagnostic indicating "session_name" is required.

  Scenario: Successfully open an ephemeral resource
    Given an OpenEphemeralResource request for "my_temp_session" with config `{"session_name": "active_session"}`
    And the provider successfully opens/creates the session, resulting in `{"session_id": "sess-123", "status": "active"}`
    And the operation yields private data "private_sess_123_token" and a renew_at timestamp 1 hour from now
    When the OpenEphemeralResource RPC is called
    Then the response should not contain error diagnostics
    And the response result (DynamicValue) should reflect `{"session_id": "sess-123", "status": "active"}`
    And the response should contain the private data "private_sess_123_token"
    And the response should contain a renew_at timestamp approximately 1 hour from now.

  Scenario: Open ephemeral resource is deferred
    Given an OpenEphemeralResource request for "my_temp_session" with config `{"session_name": "defer_session"}`
    And the provider needs to defer opening the session (e.g., provider config unknown)
    When the OpenEphemeralResource RPC is called
    Then the response should indicate the operation is deferred (e.g., reason PROVIDER_CONFIG_UNKNOWN)
    And the response result, private data, and renew_at might be null/empty.

  Scenario: Open ephemeral resource fails (e.g., API error, quota exceeded)
    Given an OpenEphemeralResource request for "my_temp_session" with config `{"session_name": "fail_session"}`
    And the provider fails to open the session due to an external error
    When the OpenEphemeralResource RPC is called
    Then the response should contain an error diagnostic explaining the failure
    And the response result, private data, and renew_at might be null/empty.

  Scenario: Successfully renew an ephemeral resource
    Given an active "my_temp_session" was opened with private data "private_sess_abc_token"
    And a RenewEphemeralResource request is made for "my_temp_session" with this private data
    And the provider successfully renews the session, optionally updating private data to "private_sess_abc_renewed" and setting a new renew_at timestamp 30 minutes from now
    When the RenewEphemeralResource RPC is called
    Then the response should not contain error diagnostics
    And the response may contain updated private data "private_sess_abc_renewed"
    And the response should contain a new renew_at timestamp approximately 30 minutes from now.

  Scenario: Renew ephemeral resource fails (e.g., session expired, invalid private data)
    Given a RenewEphemeralResource request is made for "my_temp_session" with invalid or expired private data "invalid_token"
    When the RenewEphemeralResource RPC is called
    Then the response should contain an error diagnostic (e.g., "Invalid session token" or "Session expired")
    And the response's renew_at and private data might be null/empty.

  Scenario: Renew an ephemeral resource that does not require private data
    # Some ephemeral resources might be identified by type_name only for renewal if they are singletons or globally managed.
    Given "my_temp_session" renewal does not rely on specific private data from Open (or it's optional)
    And a RenewEphemeralResource request is made for "my_temp_session" with null/empty private data
    And the provider successfully renews it
    When the RenewEphemeralResource RPC is called
    Then the response should not contain error diagnostics
    And a new renew_at timestamp should be returned.

  Scenario: Successfully close an ephemeral resource
    Given an active "my_temp_session" was opened with private data "private_sess_xyz_token_to_close"
    And a CloseEphemeralResource request is made for "my_temp_session" with this private data
    And the provider successfully closes/terminates the session
    When the CloseEphemeralResource RPC is called
    Then the response should not contain error diagnostics.

  Scenario: Close ephemeral resource fails (e.g., session already closed, error during termination)
    Given a CloseEphemeralResource request is made for "my_temp_session" with private data for an already closed session
    When the CloseEphemeralResource RPC is called
    Then the response should contain an error diagnostic (e.g., "Session not found or already closed").

  Scenario: Close an ephemeral resource that does not require private data
    Given "my_temp_session" closure does not rely on specific private data (or it's optional)
    And a CloseEphemeralResource request is made for "my_temp_session" with null/empty private data
    And the provider successfully closes it
    When the CloseEphemeralResource RPC is called
    Then the response should not contain error diagnostics.

  Scenario: OpenEphemeralResource with client capabilities
    Given an OpenEphemeralResource request for "my_temp_session" includes client capabilities (e.g., `deferral_allowed = true`)
    When the OpenEphemeralResource RPC is called
    Then the provider should acknowledge these capabilities
    And if deferral is needed and allowed, a deferred response is permissible.

  Scenario: Handle gRPC errors for ValidateEphemeralResourceConfig
    Given the provider's ValidateEphemeralResourceConfig RPC will return a gRPC error
    When the ValidateEphemeralResourceConfig RPC is called
    Then the overall operation should result in an error diagnostic reflecting the gRPC error.

  Scenario: Handle gRPC errors for OpenEphemeralResource
    Given the provider's OpenEphemeralResource RPC will return a gRPC error
    When the OpenEphemeralResource RPC is called
    Then the overall operation should result in an error diagnostic reflecting the gRPC error.

  Scenario: Handle gRPC errors for RenewEphemeralResource
    Given the provider's RenewEphemeralResource RPC will return a gRPC error
    When the RenewEphemeralResource RPC is called
    Then the overall operation should result in an error diagnostic reflecting the gRPC error.

  Scenario: Handle gRPC errors for CloseEphemeralResource
    Given the provider's CloseEphemeralResource RPC will return a gRPC error
    When the CloseEphemeralResource RPC is called
    Then the overall operation should result in an error diagnostic reflecting the gRPC error.

  Scenario: OpenEphemeralResource returns no specific renew_at time (e.g. session is indefinite or managed externally)
    Given an OpenEphemeralResource request for "my_temp_session"
    And the provider opens a session that does not have an explicit renewal deadline from the provider's perspective
    When the OpenEphemeralResource RPC is called
    Then the response's renew_at field should be null/empty (not set).

  Scenario: RenewEphemeralResource returns no specific renew_at time
    Given a RenewEphemeralResource request for "my_temp_session"
    And the provider renews a session that now has no explicit further renewal deadline
    When the RenewEphemeralResource RPC is called
    Then the response's renew_at field should be null/empty.

  Scenario: OpenEphemeralResource returns no private data
    Given an OpenEphemeralResource request for "my_temp_session"
    And the opened session does not require any private data for subsequent Renew/Close calls (e.g. identified by type_name only)
    When the OpenEphemeralResource RPC is called
    Then the response's private field should be null/empty.

  Scenario: RenewEphemeralResource returns no private data (or same as input)
    Given a RenewEphemeralResource request for "my_temp_session" with some private data
    And the renewal process does not alter or generate new private data
    When the RenewEphemeralResource RPC is called
    Then the response's private field should be null/empty or the same as input if that's the convention.

  Scenario: Attempt to Validate, Open, Renew, or Close an unknown ephemeral resource type_name
    Given a request for an unknown ephemeral resource type "unknown_temp_type" for ValidateEphemeralResourceConfig RPC
    When the ValidateEphemeralResourceConfig RPC is called
    Then the response should contain an error diagnostic indicating "unknown_temp_type" is not valid.
    # Repeat for Open, Renew, Close RPCs with similar expectation.
    Given a request for an unknown ephemeral resource type "unknown_temp_type" for OpenEphemeralResource RPC
    When the OpenEphemeralResource RPC is called
    Then the response should contain an error diagnostic indicating "unknown_temp_type" is not valid.
    Given a request for an unknown ephemeral resource type "unknown_temp_type" for RenewEphemeralResource RPC
    When the RenewEphemeralResource RPC is called
    Then the response should contain an error diagnostic indicating "unknown_temp_type" is not valid.
    Given a request for an unknown ephemeral resource type "unknown_temp_type" for CloseEphemeralResource RPC
    When the CloseEphemeralResource RPC is called
    Then the response should contain an error diagnostic indicating "unknown_temp_type" is not valid.

  Scenario: Ephemeral resource lifecycle with msgpack encoded config/result
    Given an OpenEphemeralResource request for "my_temp_session" with config `{"session_name": "msgpack_session"}` (msgpack encoded)
    And the provider opens the session, resulting in `{"session_id": "sess-mpk-456", "status": "active_mpk"}` (msgpack encoded for result)
    When the OpenEphemeralResource RPC is called
    Then the response result (DynamicValue.msgpack) should correctly reflect the session state.

  Scenario: Ephemeral resource lifecycle with JSON encoded config/result
    Given an OpenEphemeralResource request for "my_temp_session" with config `{"session_name": "json_session"}` (JSON encoded)
    And the provider opens the session, resulting in `{"session_id": "sess-json-789", "status": "active_json"}` (JSON encoded for result)
    When the OpenEphemeralResource RPC is called
    Then the response result (DynamicValue.json) should correctly reflect the session state.
