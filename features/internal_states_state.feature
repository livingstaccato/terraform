# Source Go File: internal/states/state.go
# Source Go Test: internal/states/state_test.go

Feature: Terraform State Management
  This feature describes the structure and manipulation of Terraform's state,
  including modules, resources, outputs, and provider configurations.
  It also covers operations like moving state elements.

  Background:
    Given a new Terraform state object

  Scenario: Initial state structure
    Then the state should have a root module
    And the root module address should be ""
    And the state should have no root output values
    And the state should be considered empty
    And the state should not have any managed resource instance objects

  Scenario: Managing Modules
    When a module instance "module.child" is ensured in the state
    Then a module with address "module.child" should exist in the state
    And the state should not be considered empty (due to new module presence)
    When the module instance "module.child" is removed from the state
    Then a module with address "module.child" should not exist in the state
    # Assuming removing an empty module makes the state empty again if only root outputs are also empty
    # And the state should be considered empty (if no other resources/outputs)

  Scenario: Attempting to remove the root module
    When an attempt is made to remove the root module from the state
    Then the operation should panic with message "attempted to remove root module"

  Scenario: Managing Root Output Values
    Given an absolute output value address for "my_output" in the root module
    And a cty.StringValue "hello world"
    When this value is set for the output address (not sensitive)
    Then the state should have a root output value named "my_output"
    And the retrieved output "my_output" should have value "hello world" and not be sensitive
    And the state should not be considered empty
    And HasRootOutputValues should return true
    When the root output value "my_output" is removed
    Then the state should not have a root output value named "my_output"
    And HasRootOutputValues should return false

  Scenario: Managing Sensitive Root Output Values
    Given an absolute output value address for "my_secret" in the root module
    And a cty.StringValue "supersecret"
    When this value is set for the output address (sensitive)
    Then the state should have a root output value named "my_secret"
    And the retrieved output "my_secret" should have value "supersecret" and be sensitive

  Scenario: Output values for non-root modules
    Given a module instance "module.child" is ensured in the state
    And an absolute output value address for "child_output" in module "module.child"
    And a cty.NumberValue 123
    When this value is set for the "child_output" address (not sensitive)
    Then the state should not have a root output value named "child_output" # Stored internally, not in State.RootOutputValues
    And retrieving output "child_output" from module "module.child" via State.OutputValue should result in nil

  Scenario: Checking for managed resource instance objects
    Given the root module
    And a resource "test_resource.my_res" with instance key 0 is added to the root module with status "ObjectReady" and provider "test/test"
      # Step definition implies setting via SetResourceInstanceCurrent or similar
    Then HasManagedResourceInstanceObjects should return true
    When the resource instance "test_resource.my_res[0]" is removed from the root module
      # Step definition implies removing the instance
    Then HasManagedResourceInstanceObjects should return false (if it was the only one)

  Scenario: Checking for managed resource instance objects (data resource)
    Given the root module
    And a data resource "data.test_source.my_data" with instance key 0 is added to the root module with status "ObjectReady" and provider "test/test"
    Then HasManagedResourceInstanceObjects should return false

  Scenario: Provider Addresses and Requirements from State
    Given the root module
    And resource "test_resource.res_a" is added to root module with provider "hashicorp/aws" version "4.0"
    And resource "test_resource.res_b" is added to root module with provider "hashicorp/google" version "3.0"
    And a module instance "module.child" is ensured
    And resource "test_resource.res_c" is added to module "module.child" with provider "hashicorp/aws" (same as root's aws)
    When ProviderAddrs is called on the state
    Then the returned list of absolute provider config addresses should contain "hashicorp/aws" (in root)
    And the returned list should contain "hashicorp/google" (in root)
    And the list should have 2 unique provider configurations
    When ProviderRequirements is called on the state
    Then the requirements should include "hashicorp/aws" with no version constraint
    And the requirements should include "hashicorp/google" with no version constraint

  # --- Move Operations ---
  # These are high-level scenarios; detailed step definitions would handle setup and verification.

  Scenario: Moving an absolute resource (MoveAbsResource - basic)
    Given the root module has resource "test_thing.foo[0]" with provider "test/test"
    When MoveAbsResource is called to move "test_thing.foo" in root to "test_thing.bar" in root
    Then the root module should not have resource "test_thing.foo"
    And the root module should have resource "test_thing.bar" containing instance key 0
    And the resource "test_thing.bar" should retain the original provider "test/test"

  Scenario: Moving an absolute resource to a new module (MoveAbsResource)
    Given the root module has resource "test_thing.foo[0]"
    When MoveAbsResource is called to move "test_thing.foo" in root to "test_thing.baz" in module "module.child" (no key)
    Then the root module should not have resource "test_thing.foo"
    And module "module.child" should exist
    And module "module.child" should have resource "test_thing.baz" containing instance key 0

  Scenario: Moving an absolute resource instance (MoveAbsResourceInstance)
    Given the root module has resource "test_thing.foo" with instance key 0
    When MoveAbsResourceInstance is called to move "test_thing.foo[0]" in root to "test_thing.foo[1]" in root
    Then the root module resource "test_thing.foo" should not have instance key 0
    And the root module resource "test_thing.foo" should have instance key 1

  Scenario: Moving a module instance (MoveModuleInstance)
    Given module "module.src[0]" exists and contains resource "test_thing.res[0]"
    When MoveModuleInstance is called to move "module.src[0]" to "module.dst[key=\"new\"]"
    Then module "module.src[0]" should not exist
    And module "module.dst[\"new\"]" should exist
    And module "module.dst[\"new\"]" should contain resource "test_thing.res[0]"
    And the resource "test_thing.res" within "module.dst[\"new\"]" should now have module path "module.dst[\"new\"]"

  # TODO: Add scenarios for:
  # - Empty() method with more complex states
  # - ModuleInstances() and Resources() (plural getters)
  # - ResourceInstanceObjectSrc() access
  # - PruneResourceHusks()
  # - MaybeMove* operations (success and no-op cases)
  # - MoveModule (moving all instances of a call)
  # - Panic conditions for move operations (src not found, dst exists, moving root module)
  # - DeepCopy verification details
  # - CheckResults handling (if it becomes relevant for cty interactions)
