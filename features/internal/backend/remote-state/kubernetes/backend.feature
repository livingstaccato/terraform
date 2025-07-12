# Metadata:
# Covers: internal/backend/remote-state/kubernetes/backend_test.go
# TestFunctions:
# - TestBackend
# - TestBackendLocks
# - TestBackendLocksSoak
# - Test_hasNumericSuffix (if this helper's logic becomes user-impacting)
# Note: TestBackend_impl is a compile-time check.

Feature: Kubernetes Remote State Backend
  This feature describes the behavior of the Kubernetes remote state backend,
  which stores Terraform state as Kubernetes Secrets and uses Leases for locking.

  Background:
    Given a Kubernetes cluster is available and configured for testing
    And the backend is configured with namespace "test-namespace" and secret_suffix "tf-state"

  Scenario: Basic State Operations with Kubernetes Backend
    When I write a new Terraform state "S1" to the backend for workspace "default"
    Then the operation should succeed
    And a Kubernetes Secret named "tfstate-test-namespace-default-tf-state" (or similar, incorporating suffix) should be created/updated with "S1" data
    And when I read the state from the backend for workspace "default"
    Then the retrieved state should be equal to "S1"
    And when I list workspaces (states) using the configured secret_suffix
    Then the list should include "default" (and others based on created Secrets)
    When I delete the state for workspace "another-ws"
    Then the operation should succeed
    And the Kubernetes Secret for "another-ws" should be deleted

  Scenario: State Locking and Unlocking with Kubernetes Backend
    Given two Kubernetes backend instances "B1" and "B2" configured for the same namespace and secret_suffix
    When "B1" acquires a lock on the "default" workspace state with lock info (ID "LockB1", User "UserA")
    Then "B1" should successfully hold the lock (a Kubernetes Lease object is created/updated)
    And when "B2" attempts to acquire a lock on the "default" workspace state
    Then "B2" should fail to acquire the lock
    When "B1" releases its lock "LockB1"
    Then the operation should succeed (the Kubernetes Lease object is updated/deleted)
    And when "B2" attempts to acquire a lock on the "default" workspace state again
    Then "B2" should successfully acquire the lock

  Scenario: Force Unlocking State with Kubernetes Backend
    Given a Kubernetes backend instance "B1" configured
    And another process "ExternalLockHolder" has acquired a lock (created a Lease object) for the "default" workspace
    When "B1" attempts to force unlock the "default" workspace state
    Then the force unlock operation should succeed (the Kubernetes Lease object is deleted)
    And when "B1" attempts to acquire a lock on the "default" workspace state
    Then "B1" should successfully acquire the lock

  Scenario: Concurrent State Locking (Soak Test)
    Given multiple Kubernetes backend client instances are configured for the same state
    When these clients concurrently attempt to acquire and release locks many times
    Then all lock and unlock operations should behave correctly without deadlocks or race conditions
    And at any time, only one client should successfully hold the lock for a given state

  Scenario Outline: Kubernetes Backend Configuration Validation and Defaults
    Given the Kubernetes backend is configured with <ConfigurationDetail>
    And relevant environment variables are <EnvVarState>
    When the backend configuration is prepared and then configured by Terraform
    Then the operation should <Outcome>
    And if it fails, the error message should contain "<ExpectedErrorMessagePart>"
    And if successful, the backend instance should reflect <ExpectedSetting>

    Examples:
      | ConfigurationDetail                               | EnvVarState                      | Outcome | ExpectedErrorMessagePart        | ExpectedSetting                                     |
      | missing 'secret_suffix'                           |                                  | fail    | "secret_suffix" is required     |                                                     |
      | secret_suffix="valid", no namespace             | KUBE_NAMESPACE="env-ns"          | succeed |                                 | namespace is "env-ns"                               |
      | secret_suffix="valid", no namespace             | KUBE_NAMESPACE is unset          | succeed |                                 | namespace is "default"                              |
      | secret_suffix="valid", load_config_file not set | KUBE_LOAD_CONFIG_FILE is unset | succeed |                                 | load_config_file is true (default)                  |
      | secret_suffix="valid", load_config_file=false   |                                  | succeed |                                 | load_config_file is false                           |
      | secret_suffix="my-state-123"                    |                                  | fail    | "secret_suffix must not end with '-<number>'" |                                         |
      | secret_suffix="my-state", labels={"app":"test"} |                                  | succeed |                                 | labels include {"app":"test"}                       |

  Scenario Outline: Kubernetes Client Configuration Methods
    Given the Kubernetes backend is configured with <ClientConfigSource>
    And appropriate mock Kubernetes API responses are set up for this source
    When the backend is configured (initializing the Kubernetes client)
    Then the Kubernetes client should be successfully configured
    And client configuration should reflect use of <ExpectedConfigSourceMechanism>

    Examples:
      | ClientConfigSource                                      | ExpectedConfigSourceMechanism     |
      | in_cluster_config=true                                  | in-cluster config                 |
      | load_config_file=true, no specific path (use default)   | default kubeconfig file           |
      | config_path="/custom/kube.cfg"                          | explicit single kubeconfig path   |
      | config_paths=["/p1/k.cfg", "/p2/k.cfg"]                 | explicit multiple kubeconfig paths|
      | host="k8s.example.com", token="tkn"                     | static host and token             |
      | host="h", client_certificate="cert", client_key="key"   | static host and client certs      |
      | exec block defined (api_version, command, args, env)    | exec plugin auth                  |
      # Note: Testing actual exec plugin requires a test harness for it.

  Scenario Outline: Handling Large State Payloads with Chunking in Kubernetes Secrets
    Given the Kubernetes backend is configured
    And a state payload of size "<PayloadSizeDescription>" (e.g., "exceeding Secret limit", "small")
    When the state payload is written to workspace "large_state_ws"
    Then the operation should succeed
    And the state should be stored in Kubernetes Secrets, potentially chunked if large
    And when the state is read back from workspace "large_state_ws"
    Then the retrieved data should match the original payload
    When a new, "<NewPayloadSize>" state payload is written to workspace "large_state_ws"
    Then any old chunks (if they existed) should be removed
    And the new state should be correctly stored
    When the state for workspace "large_state_ws" is deleted
    Then all associated Kubernetes Secrets (main and any chunks) should be removed

    Examples:
      | PayloadSizeDescription              | NewPayloadSize |
      | significantly exceeding Secret limit (e.g., 2MB) | small          |
      | small (e.g., 1KB)                   | smaller        |

  Scenario: Helper Function for Numeric Suffix Check (if relevant to user-facing naming)
    # This scenario is conditional on whether `hasNumericSuffix` impacts user-visible names or behavior.
    # For now, it's treated as an internal detail.
    Given a string utility for checking numeric suffixes with delimiter "-"
    When the utility checks "my-secret-123"
    Then it should return true
    When the utility checks "my-secret-abc"
    Then it should return false

```

Notes:
*   The BDD abstracts the Kubernetes API interactions (Secrets, Leases).
*   The naming convention for Secrets (e.g., `tfstate-<namespace>-<workspace_name>-<secret_suffix>`) is important and reflected in the "Basic State Operations" scenario. This is an assumption based on common patterns; the actual implementation in `client.go` will confirm.
*   The soak test scenario is high-level, focusing on the desired outcome of robustness.
*   The `hasNumericSuffix` scenario is included conditionally. If this helper doesn't affect user-visible naming conventions or error messages related to them, it might be too internal for BDD.

This covers `backend_test.go` for the Kubernetes backend.

Next is `internal/backend/remote-state/kubernetes/client_test.go`.
