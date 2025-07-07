# Source Go File: internal/states/resource.go
# Source Go Test: internal/states/resource_test.go (and implicitly via state_test.go)

Feature: Resource and Resource Instance State Management
  This feature describes how Terraform manages the state for individual resources
  and their specific instances, including current and deposed objects.

  Background:
    Given an absolute resource address, e.g., "test_resource.my_resource" in module "module.example"
    And a Resource state object for this address

  Scenario Outline: Managing Resource Instances within a Resource state
    Given the Resource state
    When EnsureInstance is called for instance key <KeyDescription> (e.g., IntKey 0 or StringKey "my-key")
    Then a ResourceInstance for key <KeyDescription> should exist in the Resource's Instances map
    And retrieving the instance with key <KeyDescription> using Instance() should return that same ResourceInstance
    When CreateInstance is called for a different instance key <NewKeyDescription>
    Then a ResourceInstance for key <NewKeyDescription> should also exist
    And it should be distinct from the instance for key <KeyDescription>

    Examples:
      | KeyDescription | NewKeyDescription |
      | IntKey 0       | StringKey "alpha" |
      | StringKey "beta"| IntKey 1          |

  Scenario: Initial state of a new ResourceInstance
    When a new ResourceInstance is created
    Then its Current object should be nil
    And it should have no deposed objects (empty Deposed map)
    And HasCurrent() should return false
    And HasAnyDeposed() should return false
    And HasObjects() should return false

  Scenario Outline: ResourceInstance object presence checks
    Given a ResourceInstance
    And its Current object is <CurrentObjectState> (set or nil)
    And its Deposed map is <DeposedMapState> (e.g., empty, or contains key "dk1")
    Then HasCurrent() should return <ExpectHasCurrent>
    And HasDeposed("dk1") should return <ExpectHasDeposedDk1> (assuming "dk1" is the key to check)
    And HasAnyDeposed() should return <ExpectHasAnyDeposed>
    And HasObjects() should return <ExpectHasObjects>

    Examples:
      | CurrentObjectState | DeposedMapState      | ExpectHasCurrent | ExpectHasDeposedDk1 | ExpectHasAnyDeposed | ExpectHasObjects |
      | set                | empty                | true             | false               | false               | true             |
      | nil                | contains key "dk1"   | false            | true                | true                | true             |
      | set                | contains key "dk1"   | true             | true                | true                | true             |
      | nil                | empty                | false            | false               | false               | false            |

  Scenario: Deposing the current object of a ResourceInstance
    Given a ResourceInstance with a Current object (representing some state attributes)
    When its current object is deposed (with no forced key)
    Then its Current object should become nil
    And its Deposed map should contain one entry
    And the key for this entry should be a valid, newly generated DeposedKey
    And the value should be the original Current object
    And HasCurrent() should return false
    And HasAnyDeposed() should return true

  Scenario: Attempting to depose when no current object exists
    Given a ResourceInstance with no Current object (Current is nil)
    And an empty Deposed map
    When an attempt is made to depose its current object
    Then its Current object should remain nil
    And its Deposed map should remain empty
    And the returned DeposedKey should be NotDeposed

  Scenario: Deposing the current object with a forced key
    Given a ResourceInstance with a Current object
    And a forced DeposedKey "forced_depose_key" that is not already in use
    When its current object is deposed with the forced key "forced_depose_key"
    Then its Current object should become nil
    And its Deposed map should contain one entry with key "forced_depose_key"

  Scenario: Attempting to depose with a forced key that is already in use
    Given a ResourceInstance with a Current object
    And its Deposed map already contains an entry with key "existing_key"
    When an attempt is made to depose its current object with the forced key "existing_key"
    Then the operation should panic with message containing "forced key existing_key is already in use"

  Scenario: Retrieving objects from ResourceInstance
    Given a ResourceInstance
    And its Current object is "current_obj_src"
    And its Deposed map contains {"dk1": "deposed_obj_src1", "dk2": "deposed_obj_src2"}
      # "current_obj_src" etc. are conceptual placeholders for ResourceInstanceObjectSrc pointers
    When Object(NotDeposed) is called
    Then the result should be "current_obj_src"
    When Object("dk1") is called
    Then the result should be "deposed_obj_src1"
    When Object("non_existent_key") is called
    Then the result should be nil

  Scenario: Finding an unused deposed key
    Given a ResourceInstance with an empty Deposed map
    When FindUnusedDeposedKey is called
    Then it should return a valid new DeposedKey
    Given another ResourceInstance whose Deposed map contains keys "keyA" and "keyB"
    When FindUnusedDeposedKey is called repeatedly
    Then it should eventually return a new DeposedKey different from "keyA" and "keyB"
      # This tests the intent; actual uniqueness is probabilistic but high.

  # Note: ResourceInstanceObjectSrc (containing AttrsJSON from cty.Value and AttrSensitivePaths as []cty.Path)
  # is the actual data payload. These scenarios focus on the management of pointers to these objects.
  # The DeposedKey generation and parsing functions are aliases to internal/addrs and assumed tested there.
