# Source Go File: internal/configs/hcl2shim/paths.go
# Source Go Test: internal/configs/hcl2shim/paths_test.go

Feature: HCL2 Shim Path Conversions
  This feature describes the conversion between flatmap string paths and
  cty.Path structures, primarily for identifying attributes that require
  resource replacement in legacy diffs.

  Background:
    Given the HCL2 shim environment for path conversions

  Scenario Outline: Converting flatmap key to cty.Path for RequiresReplace logic
    Given a flatmap key "<FlatmapPath>"
    And a cty.Type definition <CtyTypeJSON> for the root object
    When the internal `requiresReplacePath` logic is used to convert the flatmap key to a cty.Path
    Then the resulting cty.Path should be <ExpectedCtyPathStepsJSON>
    And no error should occur
    # Note: `requiresReplacePath` is internal; BDD tests `RequiresReplace` which uses it.
    # This scenario focuses on the path construction part.
    # Special handling for set indices (path to set itself) and map/list counts (ignored).

    Examples:
      | FlatmapPath      | CtyTypeJSON                                                                 | ExpectedCtyPathStepsJSON                                                                 |
      | "foo"            | "{\"type\":\"object\",\"attrs\":{\"foo\":\"string\"}}"                       | "[{\"type\":\"GetAttr\",\"name\":\"foo\"}]"                                               |
      | "foo.#"          | "{\"type\":\"object\",\"attrs\":{\"foo\":[\"list\",\"string\"]}}"             | "[{\"type\":\"GetAttr\",\"name\":\"foo\"}]"                                               | # Count path resolves to attribute
      | "foo.1"          | "{\"type\":\"object\",\"attrs\":{\"foo\":[\"list\",\"string\"]}}"             | "[{\"type\":\"GetAttr\",\"name\":\"foo\"},{\"type\":\"Index\",\"key_type\":\"number\",\"key_value\":1}]" |
      | "foo.1"          | "{\"type\":\"object\",\"attrs\":{\"foo\":[\"tuple\",[\"string\",\"bool\"]]}}" | "[{\"type\":\"GetAttr\",\"name\":\"foo\"},{\"type\":\"Index\",\"key_type\":\"number\",\"key_value\":1}]" |
      | "foo.24534534"   | "{\"type\":\"object\",\"attrs\":{\"foo\":[\"set\",\"string\"]}}"               | "[{\"type\":\"GetAttr\",\"name\":\"foo\"}]"                                               | # Set index resolves to set itself
      | "foo.%"          | "{\"type\":\"object\",\"attrs\":{\"foo\":[\"map\",\"string\"]}}"               | "[{\"type\":\"GetAttr\",\"name\":\"foo\"}]"                                               | # Map count path resolves to attribute
      | "foo.baz"        | "{\"type\":\"object\",\"attrs\":{\"foo\":[\"map\",\"bool\"]}}"                 | "[{\"type\":\"GetAttr\",\"name\":\"foo\"},{\"type\":\"Index\",\"key_type\":\"string\",\"key_value\":\"baz\"}]" |
      | "foo.bar.baz"    | "{\"type\":\"object\",\"attrs\":{\"foo\":[\"map\",[\"map\",\"bool\"]]}}"       | "[{\"type\":\"GetAttr\",\"name\":\"foo\"},{\"type\":\"Index\",\"key_type\":\"string\",\"key_value\":\"bar\"},{\"type\":\"Index\",\"key_type\":\"string\",\"key_value\":\"baz\"}]" |
      | "foo.bar.baz"    | "{\"type\":\"object\",\"attrs\":{\"foo\":[\"map\",{\"type\":\"object\",\"attrs\":{\"baz\":\"string\"}}]}}" | "[{\"type\":\"GetAttr\",\"name\":\"foo\"},{\"type\":\"Index\",\"key_type\":\"string\",\"key_value\":\"bar\"},{\"type\":\"GetAttr\",\"name\":\"baz\"}]" |
      | "foo.0.bar"      | "{\"type\":\"object\",\"attrs\":{\"foo\":[\"list\",{\"type\":\"object\",\"attrs\":{\"bar\":\"string\",\"baz\":\"bool\"}}]}}" | "[{\"type\":\"GetAttr\",\"name\":\"foo\"},{\"type\":\"Index\",\"key_type\":\"number\",\"key_value\":0},{\"type\":\"GetAttr\",\"name\":\"bar\"}]" |
      | "foo.bar.bop"    | "{\"type\":\"object\",\"attrs\":{\"foo\":[\"map\",\"string\"]}}"               | "[{\"type\":\"GetAttr\",\"name\":\"foo\"},{\"type\":\"Index\",\"key_type\":\"string\",\"key_value\":\"bar.bop\"}]" | # Dots in map key for primitive element type
      | "foo.bar.0.baz"  | "{\"type\":\"object\",\"attrs\":{\"foo\":[\"map\",[\"list\",[\"map\",\"string\"]]]}}" | "[{\"type\":\"GetAttr\",\"name\":\"foo\"},{\"type\":\"Index\",\"key_type\":\"string\",\"key_value\":\"bar\"},{\"type\":\"Index\",\"key_type\":\"number\",\"key_value\":0},{\"type\":\"Index\",\"key_type\":\"string\",\"key_value\":\"baz\"}]" |

  Scenario Outline: Converting flatmap key to cty.Path with errors
    Given a flatmap key "<FlatmapPath>"
    And a cty.Type definition <CtyTypeJSON> for the root object
    When the internal `requiresReplacePath` logic is used
    Then an error should occur containing "<ExpectedErrorMessage>"

    Examples:
      | FlatmapPath    | CtyTypeJSON                                                     | ExpectedErrorMessage           |
      | "attr"         | "{\"type\":\"object\",\"attrs\":{}}"                             | "attribute \\\"attr\\\" not found" |
      | "foo.bar.bang" | "{\"type\":\"object\",\"attrs\":{\"foo\":\"string\"}}"             | "invalid step \\\"bar.bang\\\""  |
      | "foo.bar.bang" | "{\"type\":\"object\",\"attrs\":{\"foo.bar\":[\"map\",\"string\"]}}" | "attribute \\\"foo\\\" not found"  |

  Scenario Outline: Processing list of flatmap attributes for RequiresReplace
    Given a list of flatmap attribute strings: <FlatmapPathsListJSON>
    And a cty.Type definition <CtyTypeJSON> for the root object
    When RequiresReplace is called with these attributes and type
    Then the resulting list of cty.Path objects should be <ExpectedCtyPathsListJSON>
    And no error should occur
    # This tests filtering of redundant paths and trimming non-GetAttrStep tails.

    Examples:
      | FlatmapPathsListJSON       | CtyTypeJSON                                                                                          | ExpectedCtyPathsListJSON                                                                                                                               |
      | "[\"foo\"]"                | "{\"type\":\"object\",\"attrs\":{\"foo\":\"string\"}}"                                                | "[ [{\"type\":\"GetAttr\",\"name\":\"foo\"}] ]"                                                                                                       |
      | "[\"foo\", \"bar\"]"         | "{\"type\":\"object\",\"attrs\":{\"foo\":\"string\",\"bar\":\"string\"}}"                              | "[ [{\"type\":\"GetAttr\",\"name\":\"foo\"}], [{\"type\":\"GetAttr\",\"name\":\"bar\"}] ]"                                                                  | # Order might vary
      | "[\"foo.bar\"]"            | "{\"type\":\"object\",\"attrs\":{\"foo\":{\"type\":\"object\",\"attrs\":{\"bar\":\"string\"}}}}"       | "[ [{\"type\":\"GetAttr\",\"name\":\"foo\"},{\"type\":\"GetAttr\",\"name\":\"bar\"}] ]"                                                                   |
      | "[\"foo.%\",\"foo.bar\"]"    | "{\"type\":\"object\",\"attrs\":{\"foo\":[\"map\",\"string\"]}}"                                      | "[ [{\"type\":\"GetAttr\",\"name\":\"foo\"}] ]"                                                                                                       | # Redundant paths due to map count and element
      | "[\"foo.#\",\"foo.1\"]"      | "{\"type\":\"object\",\"attrs\":{\"foo\":[\"list\",\"string\"]}}"                                     | "[ [{\"type\":\"GetAttr\",\"name\":\"foo\"}] ]"                                                                                                       | # Redundant paths due to list count and element (path is trimmed)
      | "[\"foo.1.baz\"]"          | "{\"type\":\"object\",\"attrs\":{\"foo\":[\"list\",{\"type\":\"object\",\"attrs\":{\"baz\":\"string\"}}]}}" | "[ [{\"type\":\"GetAttr\",\"name\":\"foo\"},{\"type\":\"Index\",\"key_type\":\"number\",\"key_value\":1},{\"type\":\"GetAttr\",\"name\":\"baz\"}] ]" |
      | "[\"foo.1.baz\", \"foo.1\"]" | "{\"type\":\"object\",\"attrs\":{\"foo\":[\"list\",{\"type\":\"object\",\"attrs\":{\"baz\":\"string\"}}]}}" | "[ [{\"type\":\"GetAttr\",\"name\":\"foo\"},{\"type\":\"Index\",\"key_type\":\"number\",\"key_value\":1},{\"type\":\"GetAttr\",\"name\":\"baz\"}] ]" | # foo.1 is trimmed and then seen as redundant by foo.1.baz

  Scenario Outline: Converting cty.Path to flatmap key using FlatmapKeyFromPath
    Given a cty.Path defined by steps: <CtyPathStepsJSON>
    When FlatmapKeyFromPath is called with this cty.Path
    Then the resulting flatmap key string should be "<ExpectedFlatmapPath>"

    Examples:
      | CtyPathStepsJSON                                                                                                                               | ExpectedFlatmapPath          |
      | "[{\"type\":\"GetAttr\",\"name\":\"force_new\"}]"                                                                                               | "force_new"                  |
      | "[{\"type\":\"GetAttr\",\"name\":\"attr\"},{\"type\":\"Index\",\"key_type\":\"number\",\"key_value\":0},{\"type\":\"GetAttr\",\"name\":\"force_new\"}]" | "attr.0.force_new"           |
      | "[{\"type\":\"GetAttr\",\"name\":\"attr\"},{\"type\":\"Index\",\"key_type\":\"string\",\"key_value\":\"key\"},{\"type\":\"GetAttr\",\"name\":\"obj_attr\"},{\"type\":\"Index\",\"key_type\":\"number\",\"key_value\":0},{\"type\":\"GetAttr\",\"name\":\"force_new\"}]" | "attr.key.obj_attr.0.force_new" |

  # Helper step definitions will be needed for:
  # - Parsing <CtyTypeJSON> into cty.Type.
  # - Parsing <ExpectedCtyPathStepsJSON> and <CtyPathStepsJSON> into cty.Path objects (list of cty.PathStep).
  # - Parsing <FlatmapPathsListJSON> into []string.
  # - Parsing <ExpectedCtyPathsListJSON> into []cty.Path.
  # - Comparing cty.Path objects (potentially with reflect.DeepEqual or custom logic for steps).
  # - Key path components for flatmap are dot-separated.
  # - `requiresReplacePath` is the core internal logic for converting a single flatmap key.
  # - `RequiresReplace` is the public function that handles lists of keys, trims paths, and de-duplicates.
  # - Trimming means removing trailing non-GetAttrSteps (like IndexStep) because only attributes themselves require replacement.
  # - cty.Path steps are GetAttrStep and IndexStep. IndexStep keys can be number or string.
