# Source Go File: internal/configs/configschema/filter.go
# Source Go Test: internal/configs/configschema/filter_test.go

Feature: Config Schema Filtering
  This feature describes how Terraform configuration schemas (blocks, attributes, nested blocks)
  can be filtered based on various criteria like deprecation status or being read-only.
  The filtering process uses cty.Path to provide context to filter functions.

  Background:
    Given an initial Terraform configuration schema definition

  Scenario: Filtering an empty schema
    Given the initial schema is an empty Block
    When the schema is filtered with any attribute filter
    And with any block filter
    Then the resulting schema should also be an empty Block
    And the original schema should remain unchanged

  Scenario: Filtering with no-operation (nil) filters
    Given the initial schema is a Block with:
      | Type       | Name   | Details                                                                 |
      | Attribute  | string | type=cty.String, required=true                                          |
      | BlockType  | list   | nesting=NestingList, attributes={"string": {type=cty.String, required=true}} |
    When the schema is filtered with a nil attribute filter
    And with a nil block filter
    Then the resulting schema should be identical to the initial schema
    And the original schema should remain unchanged

  Scenario: Filtering deprecated attributes and blocks
    Given the initial schema is a Block with:
      | Type       | Name              | Details                                                                                                |
      | Attribute  | string            | type=cty.String, optional=true                                                                         |
      | Attribute  | deprecated_string | type=cty.String, deprecated=true                                                                       |
      | Attribute  | nested            | nested_type={"attributes": {"string": {type=cty.String}, "deprecated_string": {type=cty.String, deprecated=true}}, "nesting": "NestingList"} |
      | BlockType  | list              | nesting=NestingList, attributes={"string": {type=cty.String, optional=true}}, deprecated=true           |
    When the schema is filtered using the "FilterDeprecatedAttribute" for attributes
    And using the "FilterDeprecatedBlock" for blocks
    Then the resulting schema should be a Block with: # Expected structure
      | Type       | Name   | Details                                                                 |
      | Attribute  | string | type=cty.String, optional=true                                          |
      | Attribute  | nested | nested_type={"attributes": {"string": {type=cty.String}}, "nesting": "NestingList"} |
    And the resulting schema should not have an attribute named "deprecated_string"
    And the resulting schema should not have a block type named "list"
    And the "nested" attribute in the resulting schema should not have a nested attribute "deprecated_string"
    And the original schema should remain unchanged

  Scenario: Filtering read-only attributes
    Given the initial schema is a Block with:
      | Type       | Name               | Details                                                                                                                                                             |
      | Attribute  | string             | type=cty.String, optional=true                                                                                                                                      |
      | Attribute  | read_only_string   | type=cty.String, computed=true                                                                                                                                      | # Filtered: Computed and not Optional
      | Attribute  | nested             | nested_type={"attributes": {"string": {type=cty.String, optional=true}, "read_only_string": {type=cty.String, computed=true}, "deeply_nested": {"nested_type": {"attributes": {"number":{type=cty.Number, required=true}, "read_only_number":{type=cty.Number, computed=true}}, "nesting":"NestingList"}}}, "nesting": "NestingList"} |
      | Attribute  | missing_attributes | nested_type={"nesting":"NestingList"}, computed=true                                                                                                                | # Filtered: Top-level attribute that is computed
      | BlockType  | list               | nesting=NestingList, attributes={"string": {type=cty.String, optional=true}, "read_only_string": {type=cty.String, computed=true}}                                   |
    When the schema is filtered using the "FilterReadOnlyAttribute" for attributes
    And with a nil block filter
    Then the resulting schema should be a Block with: # Expected structure
      | Type       | Name   | Details                                                                                                                                  |
      | Attribute  | string | type=cty.String, optional=true                                                                                                           |
      | Attribute  | nested | nested_type={"attributes": {"string": {type=cty.String, optional=true}, "deeply_nested": {"nested_type": {"attributes": {"number":{type=cty.Number, required=true}}, "nesting":"NestingList"}}}, "nesting": "NestingList"} |
      | BlockType  | list   | nesting=NestingList, attributes={"string": {type=cty.String, optional=true}}                                                            |
    And the resulting schema should not have an attribute named "read_only_string"
    And the resulting schema should not have an attribute named "missing_attributes"
    And the "nested" attribute in the resulting schema should not have a nested attribute "read_only_string"
    And the "deeply_nested" attribute within "nested" in the resulting schema should not have a nested attribute "read_only_number"
    And the "list" block type in the resulting schema should not have an attribute "read_only_string"
    And the original schema should remain unchanged

  Scenario: Filtering optional and computed 'id' attribute (helper schema compatibility)
    Given the initial schema is a Block with:
      | Type      | Name   | Details                                            |
      | Attribute | id     | type=cty.String, optional=true, computed=true      | # Filtered by FilterHelperSchemaIdAttribute
      | Attribute | string | type=cty.String, optional=true, computed=true      | # Not filtered
    When the schema is filtered using the "FilterHelperSchemaIdAttribute" for attributes
    And with a nil block filter
    Then the resulting schema should be a Block with:
      | Type      | Name   | Details                                            |
      | Attribute | string | type=cty.String, optional=true, computed=true      |
    And the resulting schema should not have an attribute named "id"
    And the original schema should remain unchanged

  Scenario: Using FilterOr to combine multiple attribute filters
    Given the initial schema is a Block with:
      | Type       | Name              | Details                                                      |
      | Attribute  | normal_attr       | type=cty.String, optional=true                               |
      | Attribute  | deprecated_attr   | type=cty.String, deprecated=true                             | # Filtered by FilterDeprecatedAttribute
      | Attribute  | readonly_attr     | type=cty.String, computed=true                               | # Filtered by FilterReadOnlyAttribute
      | Attribute  | id_attr           | type=cty.String, optional=true, computed=true, path_is_id=true | # Filtered by FilterHelperSchemaIdAttribute (assuming path context "id")
    When the schema is filtered for attributes using "FilterOr" with "FilterDeprecatedAttribute", "FilterReadOnlyAttribute", and "FilterHelperSchemaIdAttribute"
    And with a nil block filter
    Then the resulting schema should be a Block with:
      | Type       | Name        | Details                                                      |
      | Attribute  | normal_attr | type=cty.String, optional=true                               |
    And the resulting schema should not have an attribute named "deprecated_attr"
    And the resulting schema should not have an attribute named "readonly_attr"
    And the resulting schema should not have an attribute named "id_attr"
    And the original schema should remain unchanged

# Note: The "Details" column in the tables above is a simplified representation.
# Step definitions would need to parse these details to construct the actual
# configschema.Attribute and configschema.NestedBlock objects with their cty.Type,
# NestedType, Deprecated, Computed, Optional fields, etc.
# For nested_type, it implies an Object with further attributes or structure.
# The path_is_id=true is a conceptual flag for the BDD step to correctly simulate FilterHelperSchemaIdAttribute.
