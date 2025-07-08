# Source Go File: internal/backend/local/hook_state.go
# Source Go Test: internal/backend/local/hook_state_test.go

Feature: Local Backend State Hook
  This feature describes the behavior of the StateHook, which is a Terraform hook
  used by the local backend to manage state persistence during operations. It
  handles writing the state after updates and persisting it at intervals or when
  an operation is stopping.

  Background:
    Given a StateHook initialized with a mock StateMgr and Schemas

  Scenario: PostStateUpdate writes state to StateMgr
    Given the StateHook is initialized with a transient in-memory StateMgr
    And a sample states.State object representing the new state
    When the PostStateUpdate hook is called with the new state
    Then the hook action should be HookActionContinue
    And no error should occur
    And the StateMgr should now hold the new state

  Scenario: Intermediate state persistence based on interval
    Given the StateHook is initialized with a testPersistentState StateMgr
    And PersistInterval is set to 4 hours
    And LastPersist time is recent (e.g., now)
    And a sample states.State object
    When PostStateUpdate is called with the state
    Then the StateMgr's WriteState method should be called
    And its PersistState method should NOT be called (interval not met)
    When LastPersist time is updated to be more than 4 hours ago
    And PostStateUpdate is called again with the state
    Then the StateMgr's WriteState method should be called
    And its PersistState method should be called (interval met)

  Scenario: State persistence when stopping
    Given the StateHook is initialized with a testPersistentState StateMgr
    And PersistInterval is set to 4 hours, LastPersist is recent
    And a sample states.State object has been processed by PostStateUpdate (Written but not Persisted yet)
    When the Stopping hook is called
    Then the StateMgr's PersistState method should be called with the last written state
    When PostStateUpdate is called again with the state (after Stopping)
    Then the StateMgr's WriteState method should be called
    And its PersistState method should be called (persist on every update after stopping)

  Scenario: Conditional intermediate state persistence (StateMgr refuses to persist initially)
    Given the StateHook is initialized with a testPersistentStateThatRefusesToPersist StateMgr
      # This mock StateMgr's ShouldPersistIntermediateState returns false unless ForcePersist is true
    And PersistInterval is set to 4 hours
    And LastPersist time is more than 4 hours ago (persist normally due)
    And a sample states.State object
    When PostStateUpdate is called with the state
    Then the StateMgr's WriteState method should be called
    And its ShouldPersistIntermediateState method should be called
    And its PersistState method should NOT be called (because ShouldPersist... returned false)
    When the Stopping hook is called
      # This sets ForcePersist to true internally within the hook for the StateMgr
    Then the StateMgr's ShouldPersistIntermediateState method should be called (and return true)
    And its PersistState method should be called with the last written state

  # Note:
  # - The cty.Value aspects are indirect: states.State contains resource attributes and outputs as cty.Value.
  #   The StateHook itself primarily deals with the states.State object as a whole and triggers
  #   StateMgr methods.
  # - `testPersistentState` and `testPersistentStateThatRefusesToPersist` are mock implementations of statemgr.Full,
  #   statemgr.Writer, statemgr.Persister, and statemgr.IntermediateStateConditionalPersister.
  # - Step definitions will need to simulate these mocks and track calls to their methods.
  # - Time-based logic (PersistInterval, LastPersist) needs to be controlled in test setup.
  # - The `Schemas` field of StateHook is passed to `PersistState` but not deeply inspected in these tests.
  # - `statemgr.TestFullInitialState()` provides a sample states.State.
