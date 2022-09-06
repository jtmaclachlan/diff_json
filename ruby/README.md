# diff_json

Diffs two JSON objects and returns a left/right diff view, similar to the command line `diff` utility

## v1 Overhaul

The move from v0.x to v1.x includes a major rework and speed increase. Unfortunately, it also changes the initialization process, so if you previously used the 0.x versions, make sure to check this documentation.

## Basic Usage

The `DiffJson` module provides a `#diff` method that provides the interface for diffing and output retrieval. The basic call takes 3 arguments: old JSON document, new JSON document, and the return type.

```ruby
json1 = JSON.parse(File.read('test1.json'))
json2 = JSON.parse(File.read('test2.json'))
diff = DiffJson.diff(json1, json2, :raw) # returns the DiffJson::Diff instance
diff2 = DiffJson.diff(json1, json2, :html) # returns an instance of DiffJson::HtmlOutput, which contains pre-built markup
```

`DiffJson#diff` also takes option hashes for both the diffing process and the called output class.

```ruby
diff = DiffJson.diff(
  json1,
  json2,
  :html,
  {
    ignore_paths: [
      '/object/version_number'
    ],
    track_array_moves: false
  },
  {
    table_id_prefix: 'diff_table_1'
  }
)
```

See the documentation below for all config options

## Diff Output Types

* `:raw`: returns DiffJson::Diff object
* `:patch`: returns array of JSON Patch operations
  * NOTE: This output type only returns patch data for the main diff, it does not handle sub-diffs at this time
* `:html`: returns DiffJson::HtmlOutput object

## Diff Config Options

Default config options for an instance of DiffJson::Diff are:

```ruby
{
  count_operations: {
    '/**' => [:add, :replace, :remove, :move, :update]
  },
  ignore_paths: [],
  path_sort: :sorted,
  # Currently, this is the only allowed value for :path_sort, and an exception will be thrown if you override it
  sub_diffs: {},
  track_array_moves: true,
  track_structure_updates: false
}
```

### `count_operations`

* Set what changes are counted for which path wildcards
* Defaults to counting add, remove, replace, and move if necessary for all paths
* Also counts update operations by default, which will only happen if `track_structure_updates` is true
* A change will only be counted once by the first wildcard pattern it hits
* Default: `{'/**' => [:add, :replace, :remove, :move, :update]}`

Examples:

```ruby
# Will count only the changes to direct children of the /organization/components array
{'/organization/components/*' => [:add, :replace, :remove, :move]}
# Will count all changes within the /organization/components array
{'/organization/components/**' => [:add, :replace, :remove, :move]}
# Only find added or dropped keys within the first element of /organization/components
{'/organization/components/0/*' => [:add, :remove]}
```

### `ignore_paths`

* Sets a list of paths for which all diffing will be ignored
* Changes for these paths will not add to difference counts, and output will not highlight any changes
* Default: `[]`

### `sub_diffs`

* Allows for creating sub-diffs of a group of objects identified by a path wildcard
* Must also specify a key that has a unique value in each object
* Default: `{}`

Examples:

```ruby
# Find sub-diffs for each matching pair of children of the /organization/components array by using the component_id key
# This way, a diff will be generated for objects with a component_id of "send_mail_options" no matter where they are in the array
{
  '/organization/components/*' => {
    key: 'component_id',
    opts: {} # config options that will be passed to the DiffJson::Diff instance for the sub-diff, currently must pass an empty hash if no options are specified
  }
}
```

### `track_array_moves`

* Specifies whether or not to find equal array elements that move from one index to another
* Default: `true`

### `track_structure_updates`

* Specifies whether to add a count for structures whose sub-elements were changed
* Default: `false`

### `replace_primitives_arrays`

* Specifies whether arrays containing only primitive values in both JSON objects should be replaced wholesale, or individually patched
* Default: `false`

### `logger`

* Accepts an instance of `Logger` to use for logging gem execution messages
* Default: `Logger.new(STDOUT)`

### `log_level`

* Specifies level of detail to log, accepts `[:debug, :info, :warn, :error]`
* Default: `:warn`

## Diff Instance Methods

* `#count(count_type = :all)`
  * Takes a type of operation and returns the number of those operations
  * If count type is one of `[:ignore, :add, :replace, :remove, :move, :update]`, the total of that type of operation is returned
  * If count type is :total, the total of all counted operations is returned
  * If count type is :all or any non-valid value, the Hash of all count types is returned
* `#diff`
  * Returns the diff as a Hash, with each key being the JSON path at which an operation takes place, and the value being an array of JSON Patch style operations
* `#json_map(version = :old)`
  * Returns the map of one of the diffed JSON objects
  * The map is largely used internally, and contains a large amount of metadata about each path in a JSON object
  * Takes a version of :old or :new
* `#paths(version = :joint)`
  * Returns an array of paths in either one version of the diffed JSON objects, or the combined list of all paths in both in a sorted order
  * Takes a version of :old, :new, or :joint
* `#sub_diffs`
  * Returns a hash of generated sub-diffs
  * Each key is the combination of the sub-diff wildcard path and the value of the unique key, as
    ```ruby
    "#{wildcard_path}::#{unique_key_value}"
    #=> "/organization/components/*::send_mail_options"
    ```
  * Each value is an instance of `DiffJson::Diff` representing the sub-diff

## HtmlOutput Config Options

Default config options for an instance of DiffJson::HtmlOutput are:

```ruby
{
  table_id_prefix: 'diff_json_view_0',
  markup_type: :bootstrap
}
```

### `table_id_prefix`

* HTML element id prefix, will be appended with "_left", "_right", and "_full" for split and single element displays
* Default: "diff_json_view_0"

### `markup_type`

* What type of element to use to display the diff, may be `:bootstrap` for a Bootstrap compliant set of divs, or `:table` for, shockingly, a table
* Default: `:bootstrap`

## HtmlOutput Instance Methods

* `#diff`
  * Returns the `DiffJson::Diff` instance from which the HTML output was generated
* `#markup`
  * Returns the Hash of generated markup
  * The Hash has the following keys: `[:full, :left, :right, :sub_diffs]`
  * `:full` will return both sides of the diff in a single structure
  * `:left` and `:right` will return only that side of the diff
  * `:sub_diffs` will return a Hash of sub-diffs, with each key being the wildcard::unique identifier, and each value being an instance of DiffJson::HtmlOutput representing the sub-diff
