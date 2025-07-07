# Source Go File: internal/states/instance_object.go, internal/states/instance_object_src.go
# Source Go Test: internal/states/instance_object_test.go

Feature: Resource Instance Object Encoding and Decoding
  This feature describes how Terraform resource instance objects are encoded into a storable format
  (ResourceInstanceObjectSrc) and decoded back into an in-memory representation (ResourceInstanceObject),
  including handling of attributes (cty.Value), schema versions, sensitive data, and legacy formats.

  Background:
    Given a provider schema definition for a resource type "test_resource"
    And the schema implies a cty.Object type for attributes with fields like "name" (string), "count" (number), "config" (object)
    And the schema version is 2

  Scenario: Encoding a ResourceInstanceObject to ResourceInstanceObjectSrc
    Given a ResourceInstanceObject with:
      | Field               | Value                                                                 |
      | Value               | cty.Object({"name":"my_resource", "count":5, "config": {"setting":"A"}}) |
      | Identity            | cty.Object({"id":"res-123"}) (conforming to schema identity type)       |
      | Status              | ObjectReady                                                           |
      | Dependencies        | ["resource.foo.bar", "resource.alpha.beta"] (unsorted)                |
      | CreateBeforeDestroy | true                                                                  |
      | Private             | (some_binary_data)                                                    |
    When the ResourceInstanceObject is encoded using the provider schema (version 2)
    Then the resulting ResourceInstanceObjectSrc should have:
      | Field                 | Value                                                                                    |
      | SchemaVersion         | 2                                                                                        |
      | AttrsJSON             | (JSON representation of {"name":"my_resource", "count":5, "config": {"setting":"A"}})     |
      | AttrSensitivePaths    | (empty list)                                                                             |
      | IdentityJSON          | (JSON representation of {"id":"res-123"})                                                |
      | IdentitySchemaVersion | (schema identity version)                                                                |
      | Status                | ObjectReady                                                                              |
      | Dependencies          | ["resource.alpha.beta", "resource.foo.bar"] (sorted)                                     |
      | CreateBeforeDestroy   | true                                                                                     |
      | Private               | (same_binary_data)                                                                       |
    And its AttrsFlat should be nil

  Scenario: Encoding a ResourceInstanceObject with sensitive attributes
    Given a ResourceInstanceObject with Value:
      cty.Object({"api_key": Sensitive("secret123"), "public_info":"data", "nested": {"secret_field": Sensitive("nested_secret")}})
    And other fields are standard (Status=ObjectReady, no identity, etc.)
    When the ResourceInstanceObject is encoded using the provider schema
    Then the ResourceInstanceObjectSrc AttrsJSON should be the JSON of the unmarked value:
      {"api_key":"secret123", "public_info":"data", "nested": {"secret_field": "nested_secret"}}
    And its AttrSensitivePaths should contain cty.Path(GetAttr "api_key") and cty.Path(GetAttr "nested" -> GetAttr "secret_field") (sorted)

  Scenario: Encoding a ResourceInstanceObject with unknown values
    Given a ResourceInstanceObject with Value:
      cty.Object({"known_attr":"abc", "unknown_attr": Unknown(cty.String)})
    When the ResourceInstanceObject is encoded using the provider schema
    Then the ResourceInstanceObjectSrc AttrsJSON should represent unknown values as null:
      {"known_attr":"abc", "unknown_attr":null}

  Scenario: Encoding a ResourceInstanceObject with unsupported marks
    Given a ResourceInstanceObject with Value:
      cty.Object({"bad_mark_attr": StringValue("data").Mark("unsupported_mark")})
    When an attempt is made to encode the ResourceInstanceObject using the provider schema
    Then an error should occur containing "cannot serialize value marked as cty.NewValueMarks(\"unsupported_mark\")"

  Scenario: Decoding ResourceInstanceObjectSrc (from JSON attributes)
    Given a ResourceInstanceObjectSrc with:
      | Field                 | Value                                                                |
      | SchemaVersion         | 2                                                                    |
      | AttrsJSON             | (JSON of {"name":"decoded_res", "count":10})                         |
      | AttrSensitivePaths    | [cty.Path(GetAttr "name")]                                           |
      | IdentityJSON          | (JSON of {"uuid":"id-abc"})                                          |
      | IdentitySchemaVersion | (schema identity version)                                            |
      | Status                | ObjectTainted                                                        |
    When it is decoded using the provider schema (version 2, with matching identity schema)
    Then the resulting ResourceInstanceObject's Value should be cty.Object({"name":Sensitive("decoded_res"), "count":10})
    And its Identity should be cty.Object({"uuid":"id-abc"})
    And its Status should be ObjectTainted

  Scenario: Decoding ResourceInstanceObjectSrc (from legacy AttrsFlat)
    Given a ResourceInstanceObjectSrc with:
      | Field         | Value                                   |
      | SchemaVersion | 1                                       |
      | AttrsFlat     | {"name":"flat_res", "count":"3"}        | # Assuming schema implies count is number
      | Status        | ObjectReady                             |
    And the provider schema (version 1) implies attributes "name" (string) and "count" (number)
    When it is decoded using the provider schema (version 1)
    Then the resulting ResourceInstanceObject's Value should be cty.Object({"name":"flat_res", "count":3})
    And its Status should be ObjectReady

  Scenario: Decoding ResourceInstanceObjectSrc with JSON type mismatch
    Given a ResourceInstanceObjectSrc with AttrsJSON representing {"count":"not_a_number"}
    And the provider schema expects "count" to be cty.Number
    When an attempt is made to decode it using the provider schema
    Then an error should occur related to JSON unmarshalling or type conversion for "count"

  Scenario: Completing an attribute upgrade for ResourceInstanceObjectSrc
    Given an old ResourceInstanceObjectSrc (schema version 1, potentially with AttrsFlat)
    And a new attribute cty.Value representing the upgraded state: cty.Object({"name":"upgraded", "new_field":true})
    And the new schema version is 2 and new type is cty.Object({"name":cty.String, "new_field":cty.Bool})
    When CompleteUpgrade is called on the old Src with the new attributes, type, and schema version
    Then the resulting new ResourceInstanceObjectSrc should have SchemaVersion 2
    And its AttrsJSON should represent {"name":"upgraded", "new_field":true}
    And its AttrsFlat should be nil
    And other metadata (Private, Status, Dependencies etc.) should be copied from the old Src

  Scenario: Converting an ImportedResource to a ResourceInstanceObject
    Given a providers.ImportedResource with State cty.Object({"id":"imported-id", "region":"us-west"}) and Private data "private_ir_data"
    When NewResourceInstanceObjectFromIR is called with this ImportedResource
    Then the resulting ResourceInstanceObject should have Status ObjectReady
    And its Value should be cty.Object({"id":"imported-id", "region":"us-west"})
    And its Private data should be "private_ir_data"

  Scenario: Tainting a ResourceInstanceObject
    Given a ResourceInstanceObject with Status ObjectReady and Value cty.Object({"attr":"val"})
    When AsTainted is called
    Then a new ResourceInstanceObject should be returned
    And its Status should be ObjectTainted
    And its Value should be cty.Object({"attr":"val"}) (deep copy)
    And the original object's Status should remain ObjectReady

  # Notes:
  # - "(JSON of ...)" and "(cty.Object(...))" are conceptual representations for BDD steps.
  # - Step definitions will need to handle actual cty.Value creation, (un)marshalling, and schema setup.
  # - "Sensitive(...)" means the value is marked as sensitive.
  # - "Unknown(...)" means the value is cty.UnknownVal.
  # - Assumes schema version compatibility for Decode unless specifically testing upgrade paths.
