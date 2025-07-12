# Metadata:
# Covers: internal/addrs/map_test.go
# TestFunctions:
# - TestMap

Feature: Referenceable Address Map
  This feature describes the behavior of a map that uses referenceable addresses
  (like input variables, local values, module calls) as keys and stores string values.
  This is used for managing collections of addressed items within Terraform.

  Background:
    Given an InputVariable "var_name" with name "name"
    And a LocalValue "local_hello" with name "hello"
    And a PathAttr "path_module" with name "module"
    And a ModuleCall "mod_beep" with name "beep"
    And a ForEachAttr "each_key" with name "key" (which will not be in the map initially)

  Scenario: Populating and Querying the Map
    Given an address map initialized with:
      | Key         | Value     |
      | var_name    | "Aisling" |
    And I put the following into the map:
      | Key         | Value         |
      | local_hello | "hello"       |
      | path_module | "boop"        |
      | mod_beep    | "unrealistic" |

    When I check if "var_name" exists in the map
    Then it should exist
    When I check if "local_hello" exists in the map
    Then it should exist
    When I check if "path_module" exists in the map
    Then it should exist
    When I check if "mod_beep" exists in the map
    Then it should exist
    When I check if "each_key" exists in the map
    Then it should NOT exist

    When I get the value for "var_name" from the map
    Then the value should be "Aisling"
    When I get the value for "local_hello" from the map
    Then the value should be "hello"
    When I get the value for "path_module" from the map
    Then the value should be "boop"
    When I get the value for "mod_beep" from the map
    Then the value should be "unrealistic"
    When I get the value for "each_key" from the map (which is not present)
    Then the value should be ""

    When I get the value and existence for "var_name" from the map
    Then the value should be "Aisling" and it should exist
    When I get the value and existence for "each_key" from the map
    Then the value should be "" and it should NOT exist

  Scenario: Key Set Behavior and Element Removal
    Given an address map initialized with:
      | Key         | Value     |
      | var_name    | "Aisling" |
    And I put the following into the map:
      | Key         | Value         |
      | local_hello | "hello"       |
      | path_module | "boop"        |
      | mod_beep    | "unrealistic" |

    When I get the set of keys "KeySet1" from the map
    Then "KeySet1" should contain "var_name"
    And "KeySet1" should contain "local_hello"
    And "KeySet1" should contain "path_module"
    And "KeySet1" should contain "mod_beep"
    And "KeySet1" should NOT contain "each_key"

    When I remove "mod_beep" from the map
    Then "mod_beep" should NOT exist in the map
    And "KeySet1" (the original snapshot) should still contain "mod_beep"

    When I get a new set of keys "KeySet2" from the map
    Then "KeySet2" should NOT contain "mod_beep"
    And "KeySet2" should contain "var_name"
    And "KeySet2" should contain "local_hello"
    And "KeySet2" should contain "path_module"

```

Notes on this Gherkin:

*   The `Background` defines the address instances used in the tests.
*   I've split the test logic into two scenarios for clarity: one focusing on population and querying, and the other on key set behavior and removal.
*   The use of "KeySet1" and "KeySet2" helps to explicitly test the snapshot behavior of the `Keys()` method.
*   String values in the Gherkin (like `"Aisling"`) are quoted to match how they might be represented, though the underlying step definitions would handle the types.

Next, I will process `internal/addrs/module_call_test.go`.
