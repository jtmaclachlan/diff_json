# diff_json

Diffs two JSON objects and returns a left/right diff view, similar to the command line `diff` utility

## Basic Usage

The `Diff` class handles finding differences between two JSON objects. It will
calculate the diff on instantiation, so there's nothing to call until you need
the output.

```ruby
json1 = JSON.parse(File.read('test1.json'))
json2 = JSON.parse(File.read('test2.json'))
diff = DiffJson::Diff.new(json1, json2)
puts diff.diff # This will spit out the entire diff structure
```

## Advanced Usage

### Debug Output

Pass `debug: true` as an option during diff instantiation to write a bunch of
kinda useful garbage to STDOUT. Hooray.

```ruby
diff = DiffJson::Diff.new(json1, json2, debug: true)
```

### Ignore Object Keys (Wildcard)

When instantiating the diff object, you can pass an array of object keys that
will be ignored when performing the diff. The old and new values will be displayed,
but will not be highlighted, and no operation symbol will be placed before that
line. These keys are global, and will ignore any key in any object that occurs
in the JSON structure. Also, no difference count will be incremented.

```ruby
json1 = {
  "test1" => 1,
  "test2" => 2
}
json2 = {
  "test1" => 3,
  "test2" => 4
}
diff = DiffJson::Diff.new(json1, json2, ignore_object_keys: ['test2'])
puts diff.diff

# Output =>
# {
#   :count => {
#     :all    => 1,
#     :insert => 0,
#     :update => 1,
#     :delete => 0,
#     :move   => 0
#   },
#   :old => [
#     [" ", "{"],
#     ["-", "  \"test1\": 1,"],
#     [" ", "  \"test2\": 2,"], # No operation symbol, change uncounted
#     [" ", "}"]
#   ],
#   :new => [
#     [" ", "{"],
#     ["+", "  \"test1\": 3,"],
#     [" ", "  \"test2\": 4,"], # No operation symbol, change uncounted
#     [" ", "}"]
#   ]
# }
```

### Diff/Operation Count Filtering

I'll write some docs for this soon. It was a specialty request from my employer,
and probably rarely to be used outside of that application.

## Final Diff Structure

An instance of `Diff` will contain a data structure composed of old and new
[operator, line] pairs, as well as a series of change counts. The main diff
object can be retrieved with the `#diff` method. The output below is from the
comparison of two identical objects. `JSON.pretty_generate` is used to create
all lines, ensuring a proper representation in the diff output.

```ruby
puts diff.diff

# Output =>
# {
#   :count => {
#     :all    => 0,
#     :insert => 0,
#     :update => 0,
#     :delete => 0,
#     :move   => 0
#   },
#   :old => [
#     [" ", "["],
#     [" ", "  \"test_array\","],
#     [" ", "  0,"],
#     [" ", "  null"],
#     [" ", "]"]
#   ],
#   :new => [
#     [" ", "["],
#     [" ", "  \"test_array\","],
#     [" ", "  0,"],
#     [" ", "  null"],
#     [" ", "]"]
#   ]
# }
```

## Structured Output

diff_json will provide a few ways to output the diff view, but it is currently
limited to HTML output. Structured output is created via the `#generate_output(Symbol output_type, **generator_options)`
method. The `generator_options` parameter is passed to the output generator class.

### HTML

The HTML generator creates either a single table to represent both sides of the
diff, or a pair of tables. It provides some classes for a calling application
to apply CSS to, but provides no CSS itself.

Options/Defaults
* `:split => false`
    * Whether or not to split output into two separate tables
* `:table_id_prefix => 'diff_json_view_0'`
    * Customize ID of a given diff view, followed by "\_full", "\_left", or "\_right", as necessary

Output is returned as a single string if `split: false`, or a Hash of `:left` and
`:right` markup strings if `split: true`.
