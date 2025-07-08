# Source Go File: internal/plugin6/convert/schema.go
# Source Go Test: internal/plugin6/convert/schema_test.go

Feature: Schema Conversion between configschema and tfplugin6 Protobuf
  This feature describes how Terraform's internal configuration schemas (configschema)
  are converted to and from the tfplugin6 Protobuf format for provider communication.
  This is an update to the tfplugin5 conversions, potentially with new features like
  explicit NestedType handling within attributes.

  Background:
    Given the plugin6 schema conversion context

  Scenario Outline: Converting configschema.Block to proto.Schema_Block (tfplugin6)
    Given a configschema.Block defined as <ConfigSchemaBlockJSON>
      # Includes attributes (name, type as cty JSON, optional, computed, required, sensitive, deprecated, write_only, NestedType)
      # and block_types (name, nesting mode, nested block definition).
    When ConfigSchemaToProto (tfplugin6) is called with this block
    Then the result should be a proto.Schema_Block (tfplugin6) equivalent to <ProtoSchemaBlockJSON>
      # ProtoSchemaBlockJSON includes attributes with optional Type (JSON bytes) and optional NestedType (proto.Schema_Object).

    Examples:
      | ConfigSchemaBlockJSON                                                                                                                                                                                                                                                                                          | ProtoSchemaBlockJSON                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
      | "{\"attributes\":{\"computed\":{\"type\":[\"list\",\"bool\"],\"computed\":true},\"optional\":{\"type\":\"string\",\"optional\":true},\"required\":{\"type\":\"number\",\"required\":true},\"obj_attr\":{\"nested_type\":{\"nesting\":\"NestingSingle\",\"attributes\":{\"nested_req\":{\"type\":\"string\",\"required\":true}}},\"required\":true}}}" | "{\"attributes\":[{\"name\":\"computed\",\"type\":\"[\\\"list\\\",\\\"bool\\\"]\",\"computed\":true},{\"name\":\"obj_attr\",\"nested_type\":{\"attributes\":[{\"name\":\"nested_req\",\"type\":\"\\\"string\\\"\",\"required\":true}],\"nesting\":\"SINGLE\"},\"required\":true},{\"name\":\"optional\",\"type\":\"\\\"string\\\"\",\"optional\":true},{\"name\":\"required\",\"type\":\"\\\"number\\\"\",\"required\":true}]}" | # Attributes including one with NestedType
      | "{\"block_types\":{\"list_block\":{\"nesting\":\"NestingList\",\"block\":{}},\"single_block\":{\"nesting\":\"NestingSingle\",\"block\":{\"attributes\":{\"foo\":{\"type\":\"dynamic\",\"required\":true}}}}}}"                                                                                               | "{\"block_types\":[{\"type_name\":\"list_block\",\"nesting\":\"LIST\",\"block\":{}},{\"type_name\":\"single_block\",\"nesting\":\"SINGLE\",\"block\":{\"attributes\":[{\"name\":\"foo\",\"type\":\"\\\"dynamic\\\"\",\"required\":true}]}}]}"                                                                                                                                                              | # Nested blocks

  Scenario Outline: Converting proto.Schema_Block (tfplugin6) to configschema.Block
    Given a proto.Schema_Block (tfplugin6) defined as <ProtoSchemaBlockJSON>
      # Attributes can have either 'Type' (JSON bytes) or 'NestedType' (proto.Schema_Object).
    When ProtoToConfigSchema (tfplugin6) is called with this proto block
    Then the result should be a configschema.Block equivalent to <ConfigSchemaBlockJSON>

    Examples:
      | ProtoSchemaBlockJSON                                                                                                                                                                                                                                                                                         | ConfigSchemaBlockJSON                                                                                                                                                                                                                                                                                          |
      | "{\"attributes\":[{\"name\":\"computed\",\"type\":\"[\\\"list\\\",\\\"bool\\\"]\",\"computed\":true},{\"name\":\"obj_attr\",\"nested_type\":{\"attributes\":[{\"name\":\"nested_req\",\"type\":\"\\\"string\\\"\",\"required\":true}],\"nesting\":\"SINGLE\"},\"required\":true},{\"name\":\"optional\",\"type\":\"\\\"string\\\"\",\"optional\":true}]}" | "{\"attributes\":{\"computed\":{\"type\":[\"list\",\"bool\"],\"computed\":true},\"obj_attr\":{\"nested_type\":{\"nesting\":\"NestingSingle\",\"attributes\":{\"nested_req\":{\"type\":\"string\",\"required\":true}}},\"required\":true},\"optional\":{\"type\":\"string\",\"optional\":true}}}" |
      | "{\"block_types\":[{\"type_name\":\"list_block\",\"nesting\":\"LIST\",\"block\":{}},{\"type_name\":\"single_block\",\"nesting\":\"SINGLE\",\"block\":{\"attributes\":[{\"name\":\"foo\",\"type\":\"\\\"dynamic\\\"\",\"required\":true}]}}]}"                                                                 | "{\"block_types\":{\"list_block\":{\"nesting\":\"NestingList\",\"block\":{}},\"single_block\":{\"nesting\":\"NestingSingle\",\"block\":{\"attributes\":{\"foo\":{\"type\":\"dynamic\",\"required\":true}}}}}}"                                                                                               |

  Scenario Outline: Converting providers.IdentitySchema to proto.ResourceIdentitySchema (tfplugin6)
    Given a providers.IdentitySchema defined as <ProviderIdentitySchemaJSON>
    When ResourceIdentitySchemaToProto (tfplugin6) is called
    Then the result should be a proto.ResourceIdentitySchema (tfplugin6) equivalent to <ProtoResourceIdentitySchemaJSON>

    Examples:
      | ProviderIdentitySchemaJSON                                                                                   | ProtoResourceIdentitySchemaJSON                                                                                                                                       |
      | "{\"version\":1,\"body\":{\"attributes\":{\"optional\":{\"type\":\"string\",\"optional\":true},\"required\":{\"type\":\"number\",\"required\":true}}}}" | "{\"version\":1,\"identity_attributes\":[{\"name\":\"optional\",\"type\":\"\\\"string\\\"\",\"optional_for_import\":true},{\"name\":\"required\",\"type\":\"\\\"number\\\"\",\"required_for_import\":true}]}" |

  Scenario Outline: Converting proto.ResourceIdentitySchema_IdentityAttribute list (tfplugin6) to configschema.Object
    Given a list of proto.ResourceIdentitySchema_IdentityAttribute (tfplugin6) defined as <ProtoIdentityAttributesJSON>
    When ProtoToIdentitySchema (tfplugin6) is called
    Then the result should be a configschema.Object equivalent to <ConfigSchemaObjectJSON>

    Examples:
      | ProtoIdentityAttributesJSON                                                                                                                                     | ConfigSchemaObjectJSON                                                                                                                            |
      | "[{\"name\":\"id\",\"type\":\"\\\"string\\\"\",\"required_for_import\":true,\"description\":\"Something\"}]"                                                      | "{\"attributes\":{\"id\":{\"type\":\"string\",\"description\":\"Something\",\"required\":true}},\"nesting\":\"NestingSingle\"}"              |

  # Key differences from tfplugin5 to tfplugin6 for schema:
  # - In proto.Schema_Attribute, 'Type' (bytes for JSON cty.Type) and 'NestedType' (proto.Schema_Object) are mutually exclusive.
  #   One of them must be set if the attribute has a type.
  # - configschema.Attribute's NestedType field (*configschema.Object) maps to proto.Schema_Attribute's NestedType.
  # - configschema.Object's Nesting field (NestingSingle, NestingList, etc.) maps to proto.Schema_Object's Nesting field.

  # Helper step definitions will need to:
  # - Parse JSON into the respective Go structs (configschema.Block, configschema.Object, providers.IdentitySchema) and Protobuf messages.
  # - Handle the cty.Type JSON marshalling/unmarshalling.
  # - Handle the new proto.Schema_Object for NestedType attributes.
  # - Compare structures, using cmp with appropriate options.
  # - Note sortedKeys usage for deterministic output to Protobuf lists.
