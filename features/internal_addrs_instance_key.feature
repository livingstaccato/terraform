# Source Go File: internal/addrs/instance_key.go
# Source Go Test: internal/addrs/instance_key_test.go

Feature: Instance Key Representation and Formatting
  This feature describes how Terraform resource instance keys (from count/for_each)
  are represented, formatted as strings, and parsed from cty.Values.

  Scenario Outline: Formatting IntKey as String
    Given an IntKey with value <KeyValue>
    When the IntKey's String() method is called
    Then the result should be "<ExpectedString>"

    Examples:
      | KeyValue | ExpectedString |
      | 0        | [0]            |
      | 5        | [5]            |
      | -1       | [-1]           | # Assuming negative numbers are fine

  Scenario Outline: Formatting StringKey as String (HCL Quoted and Escaped)
    Given a StringKey with value "<KeyValue>"
    When the StringKey's String() method is called
    Then the result should be "<ExpectedString>"

    Examples:
      | KeyValue                             | ExpectedString                                  |
      | ""                                   | [""]                                            |
      | "hi"                                 | ["hi"]                                          |
      | "0"                                  | ["0"]                                           |
      | "\""                                 | ["\""]                                          | # Quote
      | "\\"                                 | ["\\\\"]                                        | # Backslash
      | "\r\n"                               | ["\\r\\n"]                                      | # Newline, carriage return
      | "\t"                                 | ["\\t"]                                         | # Tab
      | "${hello}"                           | ["$${hello}"]                                  | # Dollar curly escape
      | "%{ for thing in things }%{ endfor }" | ["%%{ for thing in things }%%{ endfor }"]     | # Percent curly escape
      | "$hello"                             | ["$hello"]                                      | # Dollar not followed by curly
      | "%hello"                             | ["%hello"]                                      | # Percent not followed by curly
      | "你好"                                 | ["你好"]                                        | # Unicode characters
      | "\u0000"                             | ["\\u0000"]                                     | # Null character unicode escape

  Scenario: Formatting WildcardKey as String
    Given a WildcardKey
    When the WildcardKey's String() method is called
    Then the result should be "[*]"

  Scenario: Formatting NoKey (nil InstanceKey) as String
    Given an InstanceKey that is NoKey (nil)
    When its String() method is called
    # Behavior for nil InstanceKey.String() is undefined by the interface alone.
    # This test assumes it would either panic or a default behavior (e.g. "<nil_key>") is implemented by a wrapper.
    # For this BDD, we'll specify it should not produce a typical key format or should be handled gracefully.
    # The Go code itself does not provide a String() method for a nil InstanceKey.
    # This scenario highlights a potential edge case for consumers of the interface.
    # If the intent is that NoKey.String() is never called, this scenario could be "NoKey should not have String() called".
    # Let's assume for now that if a NoKey (nil) is stringified by a generic process, it should be distinct.
    Then the string representation should indicate it's not a standard key (e.g., empty, "<no_key>", or behavior defined by calling code)
    # Actual Go code would likely panic if calling String() on a nil interface.
    # Let's refine this: A NoKey (nil InstanceKey) should not be directly asked for its string representation
    # without a check. This test is more about system behavior if it *were* to happen.

  # --- Scenarios for Value() method ---
  Scenario: Retrieving cty.Value from IntKey
    Given an IntKey with value 42
    When the IntKey's Value() method is called
    Then the result should be a cty.NumberValue equal to 42

  Scenario: Retrieving cty.Value from StringKey
    Given a StringKey with value "example"
    When the StringKey's Value() method is called
    Then the result should be a cty.StringValue equal to "example"

  Scenario: Retrieving cty.Value from WildcardKey
    Given a WildcardKey
    When the WildcardKey's Value() method is called
    Then the result should be cty.DynamicVal

  # --- Scenarios for ParseInstanceKey ---
  Scenario Outline: Parsing cty.Value to InstanceKey (Successful Cases)
    Given a cty.Value <CtyValueDescription>
    When ParseInstanceKey is called with this cty.Value
    Then the result should be an <ExpectedKeyType> with value <ExpectedInternalValue>
    And no error should occur

    Examples:
      | CtyValueDescription             | ExpectedKeyType | ExpectedInternalValue |
      | NumberValue 123                 | IntKey          | 123                   |
      | StringValue "test_key"          | StringKey       | "test_key"            |
      | StringValue "0"                 | StringKey       | "0"                   |
      | NumberValue 0                   | IntKey          | 0                     |

  Scenario Outline: Parsing cty.Value to InstanceKey (Failure Cases)
    Given a cty.Value <CtyValueDescription>
    When ParseInstanceKey is called with this cty.Value
    Then an error "either a string or an integer is required" should occur
    And the returned InstanceKey should be NoKey (nil)

    Examples:
      | CtyValueDescription             |
      | BoolValue true                  |
      | ListValue (empty string list)   |
      | ObjectValue (empty object)      |
      # Add cty.NullVal(cty.String) and cty.UnknownVal(cty.Number) if panic behavior is not tested separately

  # Note: ParseInstanceKey is documented to panic for null or unknown values.
  # BDD for panic conditions:
  # Scenario: Parsing null cty.Value with ParseInstanceKey
  #   Given a cty.NullVal of type cty.String
  #   When ParseInstanceKey is called with this cty.Value
  #   Then the operation should panic
  #
  # Scenario: Parsing unknown cty.Value with ParseInstanceKey
  #   Given an cty.UnknownVal of type cty.Number
  #   When ParseInstanceKey is called with this cty.Value
  #   Then the operation should panic

  # --- Scenarios for InstanceKeyLess ---
  Scenario Outline: Comparing InstanceKeys with InstanceKeyLess
    Given instanceKey1 is <Key1Description>
    And instanceKey2 is <Key2Description>
    When InstanceKeyLess(instanceKey1, instanceKey2) is called
    Then the result should be <ExpectedBool>

    Examples:
      # IntKey vs IntKey
      | Key1Description | Key2Description | ExpectedBool |
      | IntKey 0        | IntKey 1        | true         |
      | IntKey 1        | IntKey 0        | false        |
      | IntKey 5        | IntKey 5        | false        |
      # StringKey vs StringKey
      | StringKey "a"   | StringKey "b"   | true         |
      | StringKey "b"   | StringKey "a"   | false        |
      | StringKey "key" | StringKey "key" | false        |
      # IntKey vs StringKey (IntKey sorts before StringKey)
      | IntKey 100      | StringKey "0"   | true         |
      | StringKey "0"   | IntKey 100      | false        |
      # NoKey comparisons (NoKey sorts before all others)
      | NoKey           | IntKey 0        | true         |
      | IntKey 0        | NoKey           | false        |
      | NoKey           | StringKey "a"   | true         |
      | StringKey "a"   | NoKey           | false        |
      | NoKey           | NoKey           | false        |
      # WildcardKey is not directly handled by InstanceKeyLess's type sorting logic,
      # it would be compared by reference or fall into default.
      # Let's assume it's not typically sorted with concrete keys this way.
      # Or, if it were, it would be based on its underlying type if instanceKeyType could identify it.
      # Current instanceKeyType returns NoKeyType for WildcardKey.
      | WildcardKey     | IntKey 0        | false        | # WildcardKey (as NoKeyType) vs IntKeyType. NoKeyType < IntKeyType is true, but i==j is false for WildcardKey vs NoKey. This needs clarification.
      # The above WildcardKey example needs careful thought on how instanceKeyType and InstanceKeyLess interact with WildcardKey.
      # instanceKeyType(WildcardKey) returns NoKeyType.
      # So, WildcardKey vs IntKey 0 becomes: iTy=NoKeyType, jTy=IntKeyType. uint32(NoKeyType) < uint32(IntKeyType) is true.
      # So, InstanceKeyLess(WildcardKey, IntKey(0)) should be true.
      | WildcardKey     | IntKey 0        | true         |
      | IntKey 0        | WildcardKey     | false        |
      | WildcardKey     | StringKey "a"   | true         |
      | StringKey "a"   | WildcardKey     | false        |
      | WildcardKey     | NoKey           | false        | # WildcardKey (NoKeyType) vs NoKey (NoKeyType). iTy != jTy is false. iTy == IntKeyType is false. iTy == StringKeyType is false. Returns false.
      | NoKey           | WildcardKey     | true         | # NoKey vs WildcardKey (NoKeyType). i == j is false. NoKey is true.
      | WildcardKey     | WildcardKey     | false        | # i == j
