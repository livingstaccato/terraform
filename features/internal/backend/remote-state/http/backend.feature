# Metadata:
# Covers: internal/backend/remote-state/http/backend_test.go, internal/backend/remote-state/http/server_test.go (mTLS aspects)
# TestFunctions from backend_test.go:
# - TestHTTPClientFactory
# - TestHTTPClientFactoryWithEnv
# TestFunctions from server_test.go (client behavior aspects):
# - TestMTLSServer_NoCertFails
# - TestMTLSServer_WithCertPasses
# Note: TestBackend_impl is a compile-time check.

Feature: HTTP Remote State Backend Configuration and Authentication
  This feature describes how the HTTP remote state backend is configured,
  including endpoint URLs, HTTP methods, authentication (basic and mTLS), and retry settings,
  and how these can be sourced from configuration or environment variables.

  Scenario: HTTP Backend Client Initialization with Default Settings
    Given the HTTP backend is configured with only the state address "http://localhost/state"
    When the backend's HTTP client is initialized
    Then the client's state URL should be "http://localhost/state"
    And the client's state update HTTP method should be "POST"
    And the client's lock URL should be nil (or derived from state URL if applicable)
    And the client's lock HTTP method should be "LOCK"
    And the client's unlock URL should be nil (or derived from state URL if applicable)
    And the client's unlock HTTP method should be "UNLOCK"
    And no username or password should be set
    And default HTTP retry parameters should be used

  Scenario Outline: HTTP Backend Client Initialization with Custom Configuration
    Given the HTTP backend is configured with:
      | address          | <StateAddress>   |
      | update_method    | <UpdateMethod>   |
      | lock_address     | <LockAddress>    |
      | lock_method      | <LockMethod>     |
      | unlock_address   | <UnlockAddress>  |
      | unlock_method    | <UnlockMethod>   |
      | username         | <Username>       |
      | password         | <Password>       |
      | retry_max        | <RetryMax>       | # String representation
      | retry_wait_min   | <RetryWaitMin>   | # String representation (seconds)
      | retry_wait_max   | <RetryWaitMax>   | # String representation (seconds)
    When the backend's HTTP client is initialized
    Then the client's state URL should be "<StateAddress>"
    And the client's state update HTTP method should be "<UpdateMethod>"
    And the client's lock URL should be "<LockAddress>"
    And the client's lock HTTP method should be "<LockMethod>"
    And the client's unlock URL should be "<UnlockAddress>"
    And the client's unlock HTTP method should be "<UnlockMethod>"
    And the client's username should be "<Username>"
    And the client's password should be "<Password>"
    And the client's HTTP retry_max should be <RetryMaxAsInt>
    And the client's HTTP retry_wait_min should be <RetryWaitMinAsDuration>
    And the client's HTTP retry_wait_max should be <RetryWaitMaxAsDuration>

    Examples:
      | StateAddress              | UpdateMethod | LockAddress               | LockMethod | UnlockAddress             | UnlockMethod | Username | Password | RetryMax | RetryWaitMin | RetryWaitMax | RetryMaxAsInt | RetryWaitMinAsDuration | RetryWaitMaxAsDuration |
      | http://custom/state       | PUT          | http://custom/lock        | MYLOCK     | http://custom/unlock      | MYUNLOCK     | user1    | pass1    | "5"      | "10"         | "120"        | 5             | 10s                    | 120s                   |
      | http://another/state.json | PATCH        | http://another/state.lock | LOCK       | http://another/state.lock | UNLOCK       |          |          | "3"      | "5"          | "60"         | 3             | 5s                     | 60s                    |

  Scenario: HTTP Backend Client Initialization with Environment Variables
    Given the following environment variables are set for HTTP backend configuration:
      | TF_HTTP_ADDRESS          | "http://env/state"      |
      | TF_HTTP_UPDATE_METHOD    | "PUT"                   |
      | TF_HTTP_LOCK_ADDRESS     | "http://env/lock"       |
      | TF_HTTP_LOCK_METHOD      | "ENVLOCK"               |
      | TF_HTTP_UNLOCK_ADDRESS   | "http://env/unlock"     |
      | TF_HTTP_UNLOCK_METHOD    | "ENVUNLOCK"             |
      | TF_HTTP_USERNAME         | "env_user"              |
      | TF_HTTP_PASSWORD         | "env_pass"              |
      | TF_HTTP_RETRY_MAX        | "7"                     |
      | TF_HTTP_RETRY_WAIT_MIN   | "3s"                    |
      | TF_HTTP_RETRY_WAIT_MAX   | "90s"                   |
    And the HTTP backend is configured with no explicit values (all defaults from schema)
    When the backend's HTTP client is initialized
    Then the client's state URL should be "http://env/state"
    And the client's state update HTTP method should be "PUT"
    And the client's lock URL should be "http://env/lock"
    And the client's lock HTTP method should be "ENVLOCK"
    And the client's unlock URL should be "http://env/unlock"
    And the client's unlock HTTP method should be "ENVUNLOCK"
    And the client's username should be "env_user"
    And the client's password should be "env_pass"
    And the client's HTTP retry_max should be 7
    And the client's HTTP retry_wait_min should be 3s
    And the client's HTTP retry_wait_max should be 90s

  Scenario: HTTP Backend Successful mTLS Authentication
    Given a mock HTTP server requiring mTLS and configured with server certs and CA "testdata/certs/ca.cert.pem"
    And the HTTP backend is configured with:
      | address                   | (mTLS server URL)/state |
      | client_ca_certificate_pem | (content of "testdata/certs/ca.cert.pem") |
      | client_certificate_pem    | (content of "testdata/certs/client.crt")  |
      | client_private_key_pem    | (content of "testdata/certs/client.key")  |
    When the backend's HTTP client is initialized
    And I attempt to read state using the client
    Then the operation should succeed (implying mTLS handshake was successful)

  Scenario: HTTP Backend mTLS Authentication Failure (Client Cert Missing)
    Given a mock HTTP server requiring mTLS and configured with server certs and CA "testdata/certs/ca.cert.pem"
    And the HTTP backend is configured with:
      | address                   | (mTLS server URL)/state |
      | client_ca_certificate_pem | (content of "testdata/certs/ca.cert.pem") |
      # Client certificate and key are intentionally omitted
    When the backend's HTTP client is initialized
    And I attempt to read state using the client
    Then the operation should fail
    And the error message should indicate a TLS handshake failure or "certificate required"

  Scenario Outline: HTTP Backend Configuration URL and TLS Validation
    Given the HTTP backend is configured with <ConfigurationDetail>
    When the backend configuration is processed by Configure method
    Then the initialization should <Outcome>
    And if it fails, the error message should contain "<ExpectedErrorMessagePart>"

    Examples:
      | ConfigurationDetail                                     | Outcome | ExpectedErrorMessagePart                                           |
      | address="" (and TF_HTTP_ADDRESS unset)                  | fail    | "address argument is required"                                     |
      | address="ftp://invalid.scheme"                          | fail    | "address must be HTTP or HTTPS"                                    |
      | lock_address="ftp://invalid.scheme"                     | fail    | "lock_address must be HTTP or HTTPS"                               |
      | unlock_address="ftp://invalid.scheme"                   | fail    | "unlock_address must be HTTP or HTTPS"                             |
      | client_certificate_pem="cert" but no client_private_key_pem | fail    | "client_private_key_pem is set but client_certificate_pem is not"  | # Or vice-versa
      | client_private_key_pem="key" but no client_certificate_pem  | fail    | "client_certificate_pem is set but client_private_key_pem is not"  |
      | invalid retry_max (e.g., non-numeric string)            | fail    | "invalid retry_max"                                                |
      | invalid retry_wait_min (e.g., non-numeric string)       | fail    | "invalid retry_wait_min"                                           |
      | invalid retry_wait_max (e.g., non-numeric string)       | fail    | "invalid retry_wait_max"                                           |

  Scenario: HTTP Backend Default Retry Parameter Application
    Given the HTTP backend is configured with only state address "http://localhost/state" (no retry params)
    And no HTTP retry environment variables are set
    When the backend's HTTP client is initialized
    Then the client's HTTP retry_max should be 2
    And the client's HTTP retry_wait_min should be 1s
    And the client's HTTP retry_wait_max should be 30s

  Scenario: HTTP Backend Workspace Support Limitations
    Given an HTTP backend configured with address "http://localhost/state"
    When I request the StateMgr for workspace "default"
    Then the operation should succeed
    When I request the StateMgr for workspace "another_workspace"
    Then the operation should fail with 'ErrWorkspacesNotSupported'
    When I list workspaces
    Then the operation should fail with 'ErrWorkspacesNotSupported'
    When I attempt to delete workspace "any_workspace"
    Then the operation should fail with 'ErrWorkspacesNotSupported'
