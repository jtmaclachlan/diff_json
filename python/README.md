# diff_json

## Python version

---

## Basic Usage

```python
import json
from diff_json import JSONDiff

old_json = None
new_json = None

# JSON data can be passed as an encoded string...
with open("old_version.json") as ov:
    old_json = ov.read()
with open("new_version.json") as nv:
    new_json = nv.read()

# ...or as a Python object (dict, list, or tuple)
# old_json = {'a': 1}
# new_json = {'a': 2, 'b': 77}

diff = JSONDiff(old_json, new_json)
diff.run()
patch_data = diff.get_patch()
print(json.dumps(patch_data, indent=2))

"""
[
  {
    "op": "replace",
    "path": "/a",
    "value": 2
  },
  {
    "op": "add",
    "path": "/b",
    "value": 77
  }
]
"""
```

*NOTE: The value of `patch_data` above will be used in examples below.*

## Classes by process section

### Pathfinding

Each XPath within both JSON documents is cataloged. The pathfinding module provides a sortable XPath representation
class, and a sibling class that searches for an XPath and an optional wildcard for children or all descendants.

#### diff_json.pathfinding.XPath

```python
import diff_json.pathfinding.XPath
xpath1 = XPath([1, "op"])
xpath2 = XPath.from_string("/1/op")
```

Represents an XPath as a `list` of segments, such as `[1, "op"]`. When cast to a string, it will output the proper XPath
`"/1/op"`. Each XPath has an ID string representing the structure, allowing for a list of XPath objects to be sorted.

#### diff_json.pathfinding.XPathMatch

```python
from diff_json.pathfinding import XPath, XPathMatch
xpath = XPath([1, "op"])
xpm1 = XPathMatch([1, "op"], "**")
xpm2 = XPathMatch.from_path_string("/1/op/**")
xpm3 = xpath.to_match("**")
```

An XPathMatch allows for searching a list of XPath objects to find the descendants of a given path. If no wildcard is
provided, it will match that path only. The wildcard `"*"` will find the path's direct children, while `"**"` will find
all descendants.

### Mapping

JSON documents passed in for diffing are first mapped into a listing of XPaths pointing to a representative object.
While slower in finding the difference, this process greatly increases the speed of creating output data.

#### diff_json.mapping.JSONElement

```python
from diff_json.pathfinding import XPath
from diff_json.mapping import JSONElement
xpath = XPath([1, "op"])
element = JSONElement(xpath, patch_data[1]['op'])
```

Represents a single value within a JSON document, and holds a variety of metadata about that element.

#### diff_json.mapping.JSONMap

```python
from diff_json.mapping import JSONMap
map = JSONMap(patch_data)
```

This map of the entire JSON document holds a listing of all XPaths discovered, pointing to their respective JSONElement.

### Diffing

#### diff_json.diffing.JSONDiff

```python
from diff_json.diffing import JSONDiff
diff = JSONDiff([], patch_data)
```

The diff itself. During initialization, the two JSON documents will be passed to create two JSONMap objects. The diff is
not calculated immediately, but only once `diff.run()` is called. Once calculated, a patch document can be obtained by
calling `diff.get_patch()`, or it can be passed to an output generator. The JSONDiff constructor takes a number of
parameters that determine how the diff is executed: any paths that are ignored from diffing, which paths to count
as a diff operation, whether to track movement of elements within an array, etc. See the class docstring for complete
information.
