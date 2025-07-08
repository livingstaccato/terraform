# Source Go File: internal/lang/eval_context.go (implicitly, via Scope methods)
# Source Go Test: internal/lang/eval_test.go

Feature: Language Evaluation Context (Scope)
  This feature describes how the Terraform language evaluation context (Scope)
  makes various Terraform constructs (like resources, variables, locals, module outputs)
  available as cty.Value objects for HCL expression evaluation.

  Background:
    Given a Scope initialized with test data containing:
      - Count attributes: {"index": NumberIntVal(0)}
      - ForEach attributes: {"key": StringVal "a", "value": NumberIntVal 1}
      - Resources:
        - "null_resource.foo": ObjectVal {"attr": StringVal "bar"}
        - "data.null_data_source.foo": ObjectVal {"attr": StringVal "bar"}
        - "ephemeral.null_secret.foo": ObjectVal {"attr": StringVal "ephemeral"}
        - "null_resource.multi": TupleVal [ObjectVal{"attr":"multi0"}, ObjectVal{"attr":"multi1"}]
        - "null_resource.each": ObjectVal {"each0":Obj{"attr":"each0"}, "each1":Obj{"attr":"each1"}}
      - Local values: {"foo": StringVal "bar"}
      - Module outputs: {"module.foo": ObjectVal {"output0":"bar0", "output1":"bar1"}}
      - Path attributes: {"module": StringVal "foo/bar", "cwd": "/root/foo/bar", "root": "/root"}
      - Terraform attributes: {"workspace": StringVal "default"}
      - Input variables: {"baz": StringVal "boop"}
      - Root output values: {"rootoutput0": "rootbar0"} (for testing only scope)
      - Check blocks: {"check0": ObjectVal{"status":"pass"}} (for testing only scope)
      - Run blocks: {"zero": ObjectVal{"run0output0":"run0bar0"}} (for testing only scope)
    And the Scope's SelfAddr is "null_resource.multi[1]" (implying self is ObjectVal{"attr":"multi1"})

  Scenario Outline: Evaluating expressions accessing different context variables
    Given an HCL expression "<Expression>"
    When the expression is parsed and its references are analyzed
    And an evaluation context is created from the Scope for these references
    Then the evaluation context variables should contain a cty.Object representation of <ExpectedVariablesJSON>
    # Note: The test asserts equality of the whole Variables map.
    # For BDD, we assert that the expected top-level objects are present and structured correctly.
    # The `eval_test.go` also removes empty objects from the context variables for easier assertion.

    Examples:
      | Expression                      | ExpectedVariablesJSON (simplified for key objects)                                                                 |
      | "count.index"                   | "{\"count\":{\"index\":0}}"                                                                                        |
      | "each.key"                      | "{\"each\":{\"key\":\"a\"}}"                                                                                       |
      | "each.value"                    | "{\"each\":{\"value\":1}}"                                                                                         |
      | "local.foo"                     | "{\"local\":{\"foo\":\"bar\"}}"                                                                                    |
      | "null_resource.foo"             | "{\"null_resource\":{\"foo\":{\"attr\":\"bar\"}}, \"resource\":{\"null_resource\":{\"foo\":{\"attr\":\"bar\"}}}}"      | # And "resource" alias
      | "null_resource.foo.attr"        | "{\"null_resource\":{\"foo\":{\"attr\":\"bar\"}}, \"resource\":{\"null_resource\":{\"foo\":{\"attr\":\"bar\"}}}}"      |
      | "null_resource.multi"           | "{\"null_resource\":{\"multi\":[{\"attr\":\"multi0\"},{\"attr\":\"multi1\"}]}}"                                     | # Resource alias omitted for brevity
      | "null_resource.multi[1]"        | "{\"null_resource\":{\"multi\":[{\"attr\":\"multi0\"},{\"attr\":\"multi1\"}]}}"                                     | # Instance ref returns whole resource
      | "null_resource.each[\"each1\"]" | "{\"null_resource\":{\"each\":{\"each0\":{\"attr\":\"each0\"},\"each1\":{\"attr\":\"each1\"}}}}"                    |
      | "data.null_data_source.foo"     | "{\"data\":{\"null_data_source\":{\"foo\":{\"attr\":\"bar\"}}}}"                                                     |
      | "ephemeral.null_secret.foo"     | "{\"ephemeral\":{\"null_secret\":{\"foo\":{\"attr\":\"ephemeral\"}}}}"                                               |
      | "module.foo"                    | "{\"module\":{\"foo\":{\"output0\":\"bar0\",\"output1\":\"bar1\"}}}"                                                 |
      | "module.foo.output1"            | "{\"module\":{\"foo\":{\"output0\":\"bar0\",\"output1\":\"bar1\"}}}"                                                 | # Module attr ref returns whole module
      | "path.module"                   | "{\"path\":{\"module\":\"foo/bar\"}}"                                                                              |
      | "self.baz"                      | "{\"self\":{\"attr\":\"multi1\"}}"                                                                                 | # Assuming self.SelfAddr is null_resource.multi[1] which has {"attr":"multi1"}
      | "terraform.workspace"           | "{\"terraform\":{\"workspace\":\"default\"}}"                                                                      |
      | "var.baz"                       | "{\"var\":{\"baz\":\"boop\"}}"                                                                                     |
      # TestingOnly scope examples
      | "run.zero"                      | "{\"run\":{\"zero\":{\"run0output0\":\"run0bar0\",\"run0output1\":\"run0bar1\"}}}"                                   | # TestingOnly
      | "output.rootoutput0"            | "{\"output\":{\"rootoutput0\":\"rootbar0\"}}"                                                                      | # TestingOnly
      | "check.check0"                  | "{\"check\":{\"check0\":{\"status\":\"pass\"}}}"                                                                   | # TestingOnly

  Scenario Outline: Evaluating a block body using Scope.EvalBlock
    Given a HCL configuration block body: <HCLConfigBody>
    And a configschema.Block definition <SchemaJSON> for this block
    When the Scope is used to expand and then evaluate this block body against the schema
    Then the resulting cty.Value should be equivalent to <ExpectedCtyValueJSON>
    And no evaluation diagnostics should occur

    Examples:
      | HCLConfigBody                                  | SchemaJSON                                                                                                                               | ExpectedCtyValueJSON                                                                                                                               |
      | ""                                             | "{\"attributes\":{\"foo\":{\"type\":\"string\",\"optional\":true},\"list_of_obj\":{\"type\":[\"list\",{\"type\":\"object\",\"attrs\":{\"boop\":\"string\"}}],\"optional\":true}},\"block_types\":{\"bar\":{\"nesting\":\"NestingMap\",\"block\":{\"attributes\":{\"baz\":{\"type\":\"string\",\"optional\":true}}}}}" | "{\"bar\":{},\"foo\":null,\"list_of_obj\":null}"                                                                                               | # Empty block
      | "foo = \"hello\""                              | "{\"attributes\":{\"foo\":{\"type\":\"string\",\"optional\":true}},\"block_types\":{}}"                                                      | "{\"foo\":\"hello\"}"                                                                                                                              | # Literal attribute
      | "foo = local.greeting"                         | "{\"attributes\":{\"foo\":{\"type\":\"string\",\"optional\":true}},\"block_types\":{}}"                                                      | "{\"foo\":\"howdy\"}"                                                                                                                              | # Variable attribute
      | "bar \"static\" {}"                            | "{\"block_types\":{\"bar\":{\"nesting\":\"NestingMap\",\"block\":{\"attributes\":{\"baz\":{\"type\":\"string\",\"optional\":true}}}}}"        | "{\"bar\":{\"static\":{\"baz\":null}}}"                                                                                                             | # One static block
      | "dynamic \"bar\" { for_each=local.list labels=[bar.value] content { baz=bar.key } }" | "{\"block_types\":{\"bar\":{\"nesting\":\"NestingMap\",\"block\":{\"attributes\":{\"baz\":{\"type\":\"string\",\"optional\":true}}}}}"        | "{\"bar\":{\"elem0\":{\"baz\":\"0\"},\"elem1\":{\"baz\":\"1\"}}}"                                                                                     | # Dynamic blocks from list
      | "list_of_obj = [ { boop = local.greeting } ]"  | "{\"attributes\":{\"list_of_obj\":{\"type\":[\"list\",{\"type\":\"object\",\"attrs\":{\"boop\":\"string\"}}],\"optional\":true}},\"block_types\":{}}" | "{\"list_of_obj\":[{\"boop\":\"howdy\"}]}"                                                                                                            | # List-of-object attribute
      | "list_of_obj { boop = local.greeting }"        | "{\"attributes\":{\"list_of_obj\":{\"type\":[\"list\",{\"type\":\"object\",\"attrs\":{\"boop\":\"string\"}}],\"optional\":true}},\"block_types\":{}}" | "{\"list_of_obj\":[{\"boop\":\"howdy\"}]}"                                                                                                            | # List-of-object as blocks

  Scenario Outline: Evaluating a block body in "self" context using Scope.EvalSelfBlock
    Given a HCL configuration block body: <HCLConfigBody>
    And a configschema.Block definition <SchemaJSON> for this block
    And the "self" cty.Value is <SelfValueJSON>
    And the repetition key data is <KeyDataJSON> (e.g., count.index or each.key/value)
    When the Scope is used to evaluate this block body in "self" context
    Then the resulting cty.Value should be equivalent to <ExpectedCtyValueJSON>
    And no evaluation diagnostics should occur

    Examples:
      | HCLConfigBody         | SchemaJSON                                                     | SelfValueJSON          | KeyDataJSON                          | ExpectedCtyValueJSON                                  |
      | "attr = self.foo"     | "{\"attributes\":{\"attr\":{\"type\":\"string\"},\"num\":{\"type\":\"number\"}}}" | "{\"foo\":\"bar\"}"        | "{\"count_index\":0}"                | "{\"attr\":\"bar\",\"num\":null}"                      |
      | "num = count.index"   | "{\"attributes\":{\"attr\":{\"type\":\"string\"},\"num\":{\"type\":\"number\"}}}" | "{}"                   | "{\"count_index\":0}"                | "{\"attr\":null,\"num\":0}"                           |
      | "attr = each.key"     | "{\"attributes\":{\"attr\":{\"type\":\"string\"},\"num\":{\"type\":\"number\"}}}" | "{}"                   | "{\"each_key\":\"a\"}"                 | "{\"attr\":\"a\",\"num\":null}"                       |
      | "attr = path.cwd"     | "{\"attributes\":{\"attr\":{\"type\":\"string\"},\"num\":{\"type\":\"number\"}}}" | "{}"                   | "{}"                                 | "{\"attr\":\"/root/foo/bar\",\"num\":null}"           | # Path attributes from main scope
      | "attr = terraform.workspace" | "{\"attributes\":{\"attr\":{\"type\":\"string\"},\"num\":{\"type\":\"number\"}}}" | "{}"                   | "{}"                                 | "{\"attr\":\"default\",\"num\":null}"                 | # Terraform attributes

  # Helper step definitions will be needed for:
  # - Parsing JSON strings into cty.Value, configschema.Block, and map[string]cty.Value (for ExpectedVariablesJSON).
  # - Setting up the initial Scope with complex test data.
  # - Comparing cty.Values for equivalence (cty.RawEquals or custom logic for JSON comparison).
  # - Simulating expression parsing and reference analysis.
  # - The ExpectedVariablesJSON in the first scenario is a simplified representation of the `ctx.Variables` map.
  # - The test data for "self" in the first scenario implies `SelfAddr: addrs.ResourceInstance{Resource: addrs.Resource{Type: "null_resource", Name: "multi"}, Key: addrs.IntKey(1)}` which corresponds to `cty.ObjectVal(map[string]cty.Value{"attr": cty.StringVal("multi1")})`.
  # - For EvalSelfBlock, KeyDataJSON needs to represent instances.RepetitionData.
