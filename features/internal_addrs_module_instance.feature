# Source Go File: internal/addrs/module_instance.go
# Source Go Test: internal/addrs/module_instance_test.go

Feature: Module Instance Addressing
  This feature describes how Terraform module instances are addressed, parsed from strings
  or HCL traversals, formatted, and compared. Module instances account for 'count'
  and 'for_each' constructs.

  Scenario Outline: Parsing valid Module Instance strings
    Given the module instance address string "<AddressString>"
    When ParseModuleInstanceStr is called with this string
    Then the parsing should succeed without diagnostics
    And the resulting ModuleInstance should have <NumSteps> step(s)
    And its string representation should be "<ExpectedCanonicalString>"
    # Further checks on specific steps can be added if needed:
    # e.g., And step <N> should have name "<Name>" and key "<KeyString>" or type <KeyType>

    Examples:
      | AddressString                             | NumSteps | ExpectedCanonicalString                   |
      | ""                                        | 0        | ""                                        | # Root module
      | "module.foo"                              | 1        | "module.foo"                              |
      | "module.foo[0]"                           | 1        | "module.foo[0]"                           |
      | "module.foo[\"bar\"]"                     | 1        | "module.foo[\"bar\"]"                     |
      | "module.a.module.b"                       | 2        | "module.a.module.b"                       |
      | "module.a[1].module.b[\"key\"]"           | 2        | "module.a[1].module.b[\"key\"]"           |
      | "module.a.module.b[2].module.c"           | 3        | "module.a.module.b[2].module.c"           |
      | "module.with_quotes[\"a\\\"b\"]"          | 1        | "module.with_quotes[\"a\\\"b\"]"          |
      | "module.with_escapes[\"a\\\\nbc\"]"       | 1        | "module.with_escapes[\"a\\\\nbc\"]"       |

  Scenario Outline: Parsing invalid Module Instance strings
    Given the module instance address string "<AddressString>"
    When ParseModuleInstanceStr is called with this string
    Then parsing should fail with a diagnostic containing summary "<ExpectedSummary>"
    And the diagnostic detail should be "<ExpectedDetail>" # Or check subject range

    Examples:
      | AddressString        | ExpectedSummary                   | ExpectedDetail                                                              |
      | "foo.bar"            | "Invalid module instance address" | "A module instance address must begin with \"module.\"."                    |
      | "module."            | "Invalid address operator"        | "Prefix \"module.\" must be followed by a module name."                     |
      | "module.name."       | "Invalid module instance address" | "The module instance address is followed by additional invalid content."    | # After parsing module.name, trailing dot is invalid content
      | "module.name["       | "Invalid traversal syntax"        | "Expected expression but found EOF."                                        | # HCL parsing error
      | "module.name[true]"  | "Invalid address operator"        | "Invalid module key: must be either a string or an integer."                | # From ParseModuleInstance via parseModuleInstancePrefix
      | "module..foo"        | "Invalid address operator"        | "Prefix \"module.\" must be followed by a module name."                     | # Empty name after first module.
      | "resource.aws_instance.foo" | "Invalid module instance address" | "A module instance address must begin with \"module.\"."       |

  Scenario Outline: Formatting ModuleInstance to String
    Given a ModuleInstance constructed with the steps: <StepsDefinition> # e.g., "[{\"name\":\"foo\", \"key_type\":\"Int\", \"key_value\":0}, ...]"
    When its String() method is called
    Then the result should be "<ExpectedString>"

    Examples:
      | StepsDefinition                                                                 | ExpectedString                            |
      | []                                                                              | ""                                        | # Root module
      | [{"name":"foo"}]                                                                | "module.foo"                              |
      | [{"name":"foo", "key_type":"Int", "key_value":0}]                               | "module.foo[0]"                           |
      | [{"name":"foo", "key_type":"String", "key_value":"bar"}]                         | "module.foo[\"bar\"]"                     |
      | [{"name":"a"}, {"name":"b"}]                                                    | "module.a.module.b"                       |
      | [{"name":"a", "key_type":"Int", "key_value":1}, {"name":"b", "key_type":"String", "key_value":"key"}] | "module.a[1].module.b[\"key\"]"           |
      | [{"name":"a", "key_type":"String", "key_value":"a\\\"b"}]                        | "module.a[\"a\\\"b\"]"                    |

  Scenario Outline: ModuleInstance Equality
    Given moduleInstance1 is parsed from "<String1>"
    And moduleInstance2 is parsed from "<String2>"
    When moduleInstance1.Equal(moduleInstance2) is called
    Then the result should be <ExpectedEquality>

    Examples:
      | String1                               | String2                               | ExpectedEquality |
      | "module.foo"                          | "module.foo"                          | true             |
      | "module.foo"                          | "module.bar"                          | false            |
      | "module.foo[0]"                       | "module.foo[0]"                       | true             |
      | "module.foo[0]"                       | "module.foo[\"0\"]"                   | false            | # IntKey vs StringKey
      | "module.foo[0]"                       | "module.foo[1]"                       | false            |
      | "module.a.module.b"                   | "module.a.module.b"                   | true             |
      | "module.a.module.b"                   | "module.a.module.c"                   | false            |
      | "module.a.module.b"                   | "module.a"                            | false            | # Different length
      | ""                                    | ""                                    | true             | # Root vs Root

  Scenario Outline: ModuleInstance IsDeclaredByCall
    Given a ModuleInstance parsed from "<InstanceString>"
    And an AbsModuleCall with parent module parsed from "<CallParentString>" and call name "<CallName>"
    When <InstanceString>.IsDeclaredByCall(<CallParentString>, <CallName>) is called
    Then the result should be <ExpectedResult>

    Examples:
      | InstanceString | CallParentString | CallName | ExpectedResult |
      | "module.child" | ""               | "child"  | true           |
      | "module.child" | "module.parent"  | "child"  | false          | # Instance is not in parent
      | "module.parent.module.child" | "module.parent" | "child" | true |
      | "module.parent.module.child[0]" | "module.parent" | "child" | true | # Instance key on instance is ignored for this check
      | "module.child" | ""               | "other"  | false          | # Different call name
      | ""             | ""               | "child"  | false          | # Root instance cannot be declared by a call
      | "module.child" | ""               | ""       | false          | # Empty call name

  Scenario Outline: ModuleInstance ContainingModule
    Given a ModuleInstance parsed from "<InstanceString>"
    When its ContainingModule() method is called
    Then the string representation of the resulting ModuleInstance should be "<ExpectedContainerString>"

    Examples:
      | InstanceString                     | ExpectedContainerString            |
      | "module.parent.module.child"       | "module.parent.module.child"       |
      | "module.parent.module.child[0]"    | "module.parent.module.child"       |
      | "module.parent[0].module.child"    | "module.parent[0].module.child"    |
      | "module.parent[0].module.child[0]" | "module.parent[0].module.child"    |
      | "module.parent"                    | "module.parent"                    |
      | "module.parent[0]"                 | "module.parent"                    |
      | ""                                 | ""                                 | # Root module

  # TODO: Add scenarios for Less(), IsRoot(), Child(), Parent(), Ancestors(), IsAncestor(), Call(), AbsCall(), CallInstance(), Module(), TargetContains()
  # TODO: Add scenarios for parsing HCL Traversal directly, including with WildcardKey via TraverseSplat (if allowPartial is true)
  # TODO: Add scenarios for UnkeyedInstanceShim
