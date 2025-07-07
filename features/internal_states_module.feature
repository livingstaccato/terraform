# Source Go File: internal/states/module.go
# Source Go Test: internal/states/state_test.go (tests module interactions as part of State tests)

Feature: Module State Management
  This feature describes how Terraform manages state for individual modules,
  including resources and their instances within that module's scope.

  Background:
    Given a module address, e.g., "module.child" or "" (for root)

  Scenario: Creating a new module state
    Given a module address "module.example"
    When a new Module state is created for this address
    Then the Module's address should be "module.example"
    And the Module should have no resources
    And the Module should be considered empty

  Scenario Outline: Managing resources within a module
    Given a Module state for address "module.test"
    And a resource address "test_resource.my_res" within this module
    And a provider configuration "hashicorp/test" for this module
    When SetResourceProvider is called for "test_resource.my_res" with the provider
    Then the Module should contain a resource "test_resource.my_res"
    And this resource's provider should be "hashicorp/test"
    When Resource is called for "test_resource.my_res"
    Then a non-nil resource object should be returned
    When RemoveResource is called for "test_resource.my_res"
    Then the Module should not contain a resource "test_resource.my_res"
    And Resource is called for "test_resource.my_res"
    Then a nil resource object should be returned

  Scenario Outline: Setting current resource instance object
    Given a Module state for address "module.test"
    And a resource instance address "test_resource.res_a[0]" within this module
    And a provider configuration "test/provider"
    And an instance object source with status <InitialStatus> and schema version <InitialSchema>
      # (Step def implies AttrsJSON and other fields for the object source)
    When SetResourceInstanceCurrent is called for "test_resource.res_a[0]" with the instance object source and provider
    Then the resource "test_resource.res_a" should exist in the module
    And its provider should be "test/provider"
    And the instance "test_resource.res_a[0]" should exist
    And its current object source should have status <InitialStatus> and schema version <InitialSchema>
    When a new instance object source with status <UpdatedStatus> and schema version <UpdatedSchema> is prepared
    And SetResourceInstanceCurrent is called for "test_resource.res_a[0]" with the new instance object source and provider
    Then the current object source for "test_resource.res_a[0]" should have status <UpdatedStatus> and schema version <UpdatedSchema>

    Examples:
      | InitialStatus | InitialSchema | UpdatedStatus | UpdatedSchema |
      | ObjectReady   | 1             | ObjectTainted | 2             |

  Scenario: Setting current resource instance object to nil (removes instance if no deposed)
    Given a Module state for "module.test" with resource "test_resource.res_b[0]" having a current object and no deposed objects, and provider "P"
    When SetResourceInstanceCurrent is called for "test_resource.res_b[0]" with a nil object source and provider "P"
    Then the instance "test_resource.res_b[0]" should not exist in the resource "test_resource.res_b"
    # And if "test_resource.res_b" had no other instances, it too should be removed from the module.

  Scenario: Setting current resource instance object to nil (keeps instance if deposed exist)
    Given a Module state for "module.test" with resource "test_resource.res_c[0]" having a current object and one deposed object "depkey1", and provider "P"
    When SetResourceInstanceCurrent is called for "test_resource.res_c[0]" with a nil object source and provider "P"
    Then the instance "test_resource.res_c[0]" should still exist
    And its current object source should be nil
    And it should still have the deposed object "depkey1"

  Scenario Outline: Setting deposed resource instance object
    Given a Module state for address "module.test"
    And a resource instance address "test_resource.res_d[key=\"X\"]" within this module
    And a provider configuration "test/provider"
    And a deposed key "reason1"
    And an instance object source with status <Status> and schema version <Schema>
    When SetResourceInstanceDeposed is called for "test_resource.res_d[\"X\"]" with key "reason1", the object source, and provider
    Then resource "test_resource.res_d" should exist and its provider should be "test/provider"
    And instance "test_resource.res_d[\"X\"]" should exist
    And it should have a deposed object for key "reason1" with status <Status> and schema version <Schema>
    When SetResourceInstanceDeposed is called for "test_resource.res_d[\"X\"]" with key "reason1", a nil object source, and provider
    Then instance "test_resource.res_d[\"X\"]" should not have a deposed object for key "reason1"
    # And if this leaves the instance with no current/deposed objects, it is removed.

    Examples:
      | Status      | Schema |
      | ObjectReady | 3      |

  Scenario Outline: Forgetting resource instances
    Given a Module state for "module.test"
    And resource "test_resource.forgettable[0]" exists with a current object and deposed object "dk1", provider "P"
    When <ForgetTarget> is called for "test_resource.forgettable[0]" (and deposed key "dk1" if applicable)
    Then <ExpectedOutcome> for instance "test_resource.forgettable[0]"

    Examples:
      | ForgetTarget                        | ExpectedOutcome                                                                |
      | ForgetResourceInstanceAll           | the instance should not exist                                                  |
      | ForgetResourceInstanceCurrent       | the instance should exist, its current object should be nil, deposed "dk1" should exist |
      | ForgetResourceInstanceDeposed (dk1) | the instance should exist, its current object should exist, deposed "dk1" should not exist |

  Scenario: Deposing a current object
    Given a Module state for "module.test" with resource "test_resource.my_inst[0]" having a current object (status Ready, schema 1) and provider "P"
    When its current object is deposed with forced key "manual_depose"
    Then instance "test_resource.my_inst[0]" current object should be nil
    And instance "test_resource.my_inst[0]" should have a deposed object for key "manual_depose" with original status Ready and schema 1
    And the returned deposed key should be "manual_depose"

  Scenario: Restoring a deposed object
    Given a Module state for "module.test" with resource "test_resource.my_inst[0]" having no current object, but a deposed object "dk_restore" (status Ready, schema 2), and provider "P"
    When deposed object "dk_restore" for instance "test_resource.my_inst[0]" is restored
    Then instance "test_resource.my_inst[0]" current object should have status Ready and schema 2
    And instance "test_resource.my_inst[0]" should not have a deposed object for key "dk_restore"
    And the operation should return true (success)

  Scenario: Attempting to restore a deposed object when current exists
    Given a Module state for "module.test" with resource "test_resource.my_inst[0]" having a current object and a deposed object "dk_norestore", and provider "P"
    When an attempt is made to restore deposed object "dk_norestore" for instance "test_resource.my_inst[0]"
    Then the instance's current object should remain unchanged
    And the deposed object "dk_norestore" should still exist
    And the operation should return false (failure)

  Scenario: Pruning resource husks from a module
    Given a Module state for "module.test" with:
      1. Resource "test_resource.res_with_instance[0]" (has a current object)
      2. Resource "test_resource.res_no_instance" (has no instances)
    And provider "P" for both
    When PruneResourceHusks is called on the module state
    Then resource "test_resource.res_with_instance" should still exist
    And resource "test_resource.res_no_instance" should not exist

  Scenario: Checking if a module is empty
    Given a Module state for "module.empty_check"
    Then the module should be considered empty
    When resource "test_resource.temp[0]" is added to it with provider "P"
    Then the module should not be considered empty
    When resource "test_resource.temp" is removed from it
    Then the module should be considered empty

  # Note: "instance object source" implies ResourceInstanceObjectSrc fields like AttrsJSON, SchemaVersion, Status, etc.
  # These are simplified in BDD steps but would be fully represented in step definitions.
  # The cty.Value aspects are primarily within AttrsJSON (as serialized JSON) and AttrSensitivePaths (as []cty.Path)
  # of the ResourceInstanceObjectSrc, which this module's methods manage.
