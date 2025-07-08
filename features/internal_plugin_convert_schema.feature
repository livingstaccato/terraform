# Source Go File: internal/plugin/convert/schema.go
# Source Go Test: internal/plugin/convert/schema_test.go

Feature: Schema Conversion between configschema and tfplugin5 Protobuf
  This feature describes how Terraform's internal configuration schemas (configschema)
  are converted to and from the tfplugin5 Protobuf format for provider communication.
  This involves translating attributes, nested blocks, and their properties like
  cty.Type, optional, computed, required, nesting mode, etc.

  Background:
    Given the plugin schema conversion context

  Scenario Outline: Converting configschema.Block to proto.Schema_Block
    Given a configschema.Block defined as <ConfigSchemaBlockJSON>
      # This JSON will represent the structure of configschema.Block,
      # including attributes (name, type as cty JSON, optional, computed, required, sensitive, deprecated)
      # and block_types (name, nesting mode, nested block definition).
    When ConfigSchemaToProto is called with this block
    Then the result should be a proto.Schema_Block equivalent to <ProtoSchemaBlockJSON>
      # This JSON will represent the expected proto.Schema_Block structure,
      # with types marshalled to JSON byte arrays and nesting modes as enums.

    Examples:
      | ConfigSchemaBlockJSON                                                                                                                               | ProtoSchemaBlockJSON                                                                                                                                                                                                                                                                                                                                                                                       |
      | "{\"attributes\":{\"computed\":{\"type\":[\"list\",\"bool\"],\"computed\":true},\"optional\":{\"type\":\"string\",\"optional\":true},\"required\":{\"type\":\"number\",\"required\":true}}}" | "{\"attributes\":[{\"name\":\"computed\",\"type\":\"[\\\"list\\\",\\\"bool\\\"]\",\"computed\":true},{\"name\":\"optional\",\"type\":\"\\\"string\\\"\",\"optional\":true},{\"name\":\"required\",\"type\":\"\\\"number\\\"\",\"required\":true}]}"                                                                                                                                                | # Basic attributes
      | "{\"block_types\":{\"list_block\":{\"nesting\":\"NestingList\",\"block\":{}},\"map_block\":{\"nesting\":\"NestingMap\",\"block\":{}},\"set_block\":{\"nesting\":\"NestingSet\",\"block\":{}},\"single_block\":{\"nesting\":\"NestingSingle\",\"block\":{\"attributes\":{\"foo\":{\"type\":\"dynamic\",\"required\":true}}}}}}" | "{\"block_types\":[{\"type_name\":\"list_block\",\"nesting\":\"LIST\",\"block\":{}},{\"type_name\":\"map_block\",\"nesting\":\"MAP\",\"block\":{}},{\"type_name\":\"set_block\",\"nesting\":\"SET\",\"block\":{}},{\"type_name\":\"single_block\",\"nesting\":\"SINGLE\",\"block\":{\"attributes\":[{\"name\":\"foo\",\"type\":\"\\\"dynamic\\\"\",\"required\":true}]}}]}" | # Nested blocks with different nesting modes
      | "{\"description\":\"Test desc\",\"deprecated\":true}"                                                                                                   | "{\"description\":\"Test desc\",\"deprecated\":true}"                                                                                                                                                                                                                                                                                                                                                             | # Description and deprecation

  Scenario Outline: Converting proto.Schema_Block to configschema.Block
    Given a proto.Schema_Block defined as <ProtoSchemaBlockJSON>
      # This JSON will represent the structure of proto.Schema_Block.
      # cty.Type is represented as a JSON string within a byte array.
    When ProtoToConfigSchema is called with this proto block
    Then the result should be a configschema.Block equivalent to <ConfigSchemaBlockJSON>
      # This JSON will represent the expected configschema.Block structure.
      # cty.Type should be unmarshalled correctly.

    Examples:
      | ProtoSchemaBlockJSON                                                                                                                                                                                                                                                                  | ConfigSchemaBlockJSON                                                                                                                                                                                             |
      | "{\"attributes\":[{\"name\":\"computed\",\"type\":\"[\\\"list\\\",\\\"bool\\\"]\",\"computed\":true},{\"name\":\"optional\",\"type\":\"\\\"string\\\"\",\"optional\":true},{\"name\":\"required\",\"type\":\"\\\"number\\\"\",\"required\":true}]}"                                     | "{\"attributes\":{\"computed\":{\"type\":[\"list\",\"bool\"],\"computed\":true},\"optional\":{\"type\":\"string\",\"optional\":true},\"required\":{\"type\":\"number\",\"required\":true}}}"                               |
      | "{\"block_types\":[{\"type_name\":\"list_block\",\"nesting\":\"LIST\",\"block\":{}},{\"type_name\":\"map_block\",\"nesting\":\"MAP\",\"block\":{}},{\"type_name\":\"set_block\",\"nesting\":\"SET\",\"block\":{}},{\"type_name\":\"single_block\",\"nesting\":\"SINGLE\",\"block\":{\"attributes\":[{\"name\":\"foo\",\"type\":\"\\\"dynamic\\\"\",\"required\":true}]}}]}" | "{\"block_types\":{\"list_block\":{\"nesting\":\"NestingList\",\"block\":{}},\"map_block\":{\"nesting\":\"NestingMap\",\"block\":{}},\"set_block\":{\"nesting\":\"NestingSet\",\"block\":{}},\"single_block\":{\"nesting\":\"NestingSingle\",\"block\":{\"attributes\":{\"foo\":{\"type\":\"dynamic\",\"required\":true}}}}}}" |
      | "{\"description\":\"Test desc\",\"description_kind\":\"MARKDOWN\",\"deprecated\":true}"                                                                                                                                                                                                   | "{\"description\":\"Test desc\",\"description_kind\":\"StringMarkdown\",\"deprecated\":true}"                                                                                                                             |

  Scenario Outline: Converting providers.IdentitySchema to proto.ResourceIdentitySchema
    Given a providers.IdentitySchema defined as <ProviderIdentitySchemaJSON>
      # JSON representing providers.IdentitySchema with Version and Body (configschema.Object)
    When ResourceIdentitySchemaToProto is called
    Then the result should be a proto.ResourceIdentitySchema equivalent to <ProtoResourceIdentitySchemaJSON>
      # JSON representing proto.ResourceIdentitySchema with Version and IdentityAttributes

    Examples:
      | ProviderIdentitySchemaJSON                                                                                   | ProtoResourceIdentitySchemaJSON                                                                                                                                       |
      | "{\"version\":1,\"body\":{\"attributes\":{\"optional\":{\"type\":\"string\",\"optional\":true},\"required\":{\"type\":\"number\",\"required\":true}}}}" | "{\"version\":1,\"identity_attributes\":[{\"name\":\"optional\",\"type\":\"\\\"string\\\"\",\"optional_for_import\":true},{\"name\":\"required\",\"type\":\"\\\"number\\\"\",\"required_for_import\":true}]}" |

  Scenario Outline: Converting proto.ResourceIdentitySchema_IdentityAttribute list to configschema.Object
    Given a list of proto.ResourceIdentitySchema_IdentityAttribute defined as <ProtoIdentityAttributesJSON>
      # JSON representing a list of proto.ResourceIdentitySchema_IdentityAttribute
    When ProtoToIdentitySchema is called
    Then the result should be a configschema.Object equivalent to <ConfigSchemaObjectJSON>
      # JSON representing configschema.Object with attributes derived from the proto attributes

    Examples:
      | ProtoIdentityAttributesJSON                                                                                                                                     | ConfigSchemaObjectJSON                                                                                                                            |
      | "[{\"name\":\"id\",\"type\":\"\\\"string\\\"\",\"required_for_import\":true,\"description\":\"Something\"}]"                                                      | "{\"attributes\":{\"id\":{\"type\":\"string\",\"description\":\"Something\",\"required\":true}},\"nesting\":\"NestingSingle\"}"              |
      | "[{\"name\":\"optional\",\"type\":\"\\\"string\\\"\",\"optional_for_import\":true},{\"name\":\"required\",\"type\":\"\\\"number\\\"\",\"required_for_import\":true}]" | "{\"attributes\":{\"optional\":{\"type\":\"string\",\"optional\":true},\"required\":{\"type\":\"number\",\"required\":true}},\"nesting\":\"NestingSingle\"}" |

  # Helper step definitions will be needed for:
  # - Parsing JSON strings into configschema.Block, proto.Schema_Block, providers.IdentitySchema, proto.ResourceIdentitySchema, and lists of proto.ResourceIdentitySchema_IdentityAttribute.
  # - Handling cty.Type marshalling/unmarshalling from/to JSON strings within the schema objects.
  # - Comparing the resulting structures, potentially using cmp with custom comparers for cty.Type and ignoring unexported fields in proto messages.
  # - Note that attribute and block_type order matters for proto lists but not for configschema maps; sortedKeys is used internally for deterministic conversion to proto.
  # - Nesting modes are converted between configschema enums (e.g., NestingList) and proto enums (e.g., LIST).
  # - StringKind is converted between configschema.StringKind and proto.StringKind.
