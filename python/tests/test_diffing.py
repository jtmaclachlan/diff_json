from diff_json.diffing import JSONDiff
from diff_json.mapping import JSONElement
from diff_json.pathfinding import XPath
import diff_json.__version__ as _nothing_that_matters # ignore-glob wasn't working. so we'll just pull it in to get the coverage on it.

def test_init():
    json_diff = JSONDiff("{}", "{}")
    assert json_diff

def test_run_empty_json_strings():
    json_diff = JSONDiff("{}", "{}")
    json_diff.run()
    assert json_diff.get_patch() == []

def test_run_empty_dictionaries():
    json_diff = JSONDiff({}, {})
    json_diff.run()
    assert json_diff.get_patch() == []

def test_run_single_key_added():
    json_diff = JSONDiff({}, {"key":"value"})
    json_diff.run()
    patch = json_diff.get_patch()
    assert patch != []
    assert len(patch) == 1
    assert patch[0] == {'op': 'add', 'path': '/key', 'value': 'value'}

def test_run_single_key_added_but_ignored():
    json_diff = JSONDiff({}, {"key":"value"}, ignore_paths=["key"])
    json_diff.run()
    patch = json_diff.get_patch()
    assert patch == []

def test_run_single_key_removed():
    json_diff = JSONDiff({"key":"value"}, {})
    json_diff.run()
    patch = json_diff.get_patch()
    assert patch != []
    assert len(patch) == 1
    assert patch[0] == {'op': 'remove', 'path': '/key'}

def test_run_single_key_removed_but_ignored():
    json_diff = JSONDiff({"key":"value"}, {}, ignore_paths=["key"])
    json_diff.run()
    patch = json_diff.get_patch()
    assert patch == []

def test_count_paths_empty_json():
    json_diff = JSONDiff({}, {}, count_paths={"/key/*":["add"]})
    json_diff.run()
    patch = json_diff.get_patch()
    assert patch == []

def test_primitive_array_diff_add_primitive():
    json_diff = JSONDiff({"key":[1]}, {"key":[1,2]})
    json_diff.run()
    patch = json_diff.get_patch()
    assert len(patch) == 1
    assert patch[0] == {'op': 'add', 'path': '/key/1', 'value': 2}

def test_primitive_array_diff_remove_primitive():
    json_diff = JSONDiff({"key":[1,2]}, {"key":[1]})
    json_diff.run()
    patch = json_diff.get_patch()
    assert len(patch) == 1
    assert patch[0] == {'op': 'remove', 'path': '/key/1'}

def test_primitive_array_diff_identical_primitive():
    json_diff = JSONDiff({"key":[1,2]}, {"key":[1,2]})
    json_diff.run()
    patch = json_diff.get_patch()
    assert len(patch) == 0

def test_primitive_array_diff_add_dict():
    json_diff = JSONDiff({"key":[]}, {"key":[{"more":"stuff"}]})
    json_diff.run()
    patch = json_diff.get_patch()
    assert len(patch) == 1
    assert patch[0] == {'op': 'add', 'path': '/key/0', 'value': {'more': 'stuff'}}

def test_primitive_array_diff_remove_dict():
    json_diff = JSONDiff({"key":[{"more":"stuff"}]}, {"key":[]})
    json_diff.run()
    patch = json_diff.get_patch()
    assert len(patch) == 1
    assert patch[0] == {'op': 'remove', 'path': '/key/0'}

def test_primitive_array_diff_move_dict():
    json_diff = JSONDiff({"key":[{"first":"thing"}, {"second":"thing"}]}, {"key":[{"second":"thing"}, {"first":"thing"}]})
    json_diff.run()
    patch = json_diff.get_patch()
    assert len(patch) == 6
    assert patch[0] == {'op': 'move', 'path': '/key/0', 'from': '/key/1'}
    assert patch[1] == {'op': 'move', 'path': '/key/1', 'from': '/key/0'}
    assert patch[2] == {'op': 'remove', 'path': '/key/0/first'}
    assert patch[3] == {'op': 'add', 'path': '/key/0/second', 'value': 'thing'}
    assert patch[4] == {'op': 'add', 'path': '/key/1/first', 'value': 'thing'}
    assert patch[5] == {'op': 'remove', 'path': '/key/1/second'}

def test_primitive_array_diff_add_key():
    json_diff = JSONDiff({"key":[{"first":"thing"}]}, {"key":[{"first":"thing", "second":"thing"}]})
    json_diff.run()
    patch = json_diff.get_patch()
    assert len(patch) == 1
    assert patch[0] == {'op': 'add', 'path': '/key/0/second', 'value': 'thing'}

def test_primitive_array_diff_remove_key():
    json_diff = JSONDiff({"key":[{"first":"thing"}]}, {"key":[{}]})
    json_diff.run()
    patch = json_diff.get_patch()
    assert len(patch) == 1
    assert patch[0] == {'op': 'remove', 'path': '/key/0/first'}

def test_primitive_array_diff_modify_key():
    json_diff = JSONDiff({"key":[{"first":"thing"}]}, {"key":[{"first":"changed_thing"}]})
    json_diff.run()
    patch = json_diff.get_patch()
    assert len(patch) == 1
    assert patch[0] == {'op': 'replace', 'path': '/key/0/first', 'value': 'changed_thing'}

def test_primitive_array_diff_add_primitive_with_max_array_tracking_length():
    json_diff = JSONDiff({"key":[1,2,3]}, {"key":[1,2,3,4]}, max_array_tracking_length=1)
    json_diff.run()
    patch = json_diff.get_patch()
    assert len(patch) == 1
    assert patch[0] == {'op': 'add', 'path': '/key/3', 'value': 4}

def test_array_diff_primitive_to_non_primitive():
    json_diff = JSONDiff({"key":[{"more":"stuff"}]}, {"key":[1]})
    json_diff.run()
    patch = json_diff.get_patch()
    assert len(patch) == 1
    assert patch[0] == {'op': 'replace', 'path': '/key/0', 'value': 1}

def test_array_diff_primitive_to_non_primitive_with_track_structure_updates():
    json_diff = JSONDiff({"key":[{"more":"stuff"}]}, {"key":[1]}, track_structure_updates=True)
    json_diff.run()
    patch = json_diff.get_patch()
    assert len(patch) == 1
    assert patch[0] == {'op': 'replace', 'path': '/key/0', 'value': 1}

def test_array_diff_primitive_to_different_primitive_different_keys():
    json_diff = JSONDiff({"key1":1}, {"key2":False})
    json_diff.run()
    patch = json_diff.get_patch()
    assert len(patch) == 2
    assert patch[0] == {'op': 'remove', 'path': '/key1'}
    assert patch[1] == {'op': 'add', 'path': '/key2', 'value': False}

def test_replace_primitives_arrays():
    json_diff = JSONDiff({"key":[1]}, {"key":[4]}, replace_primitives_arrays=True)
    json_diff.run()
    patch = json_diff.get_patch()
    assert len(patch) == 1
    assert patch[0] == {'op': 'replace', 'path': '/key', 'value': [4]}

def test_diff_type_no_match(mocker):
    mocker.patch("diff_json.diffing.JSONDiff._get_diff_type", return_value="something_else")
    json_diff = JSONDiff({}, {})
    json_diff.run()
    assert json_diff.get_patch() == []

def test_diff_type_replace(mocker):
    mocker.patch("diff_json.diffing.JSONDiff._get_diff_type", return_value="replace")
    xpath = XPath("key")
    json_element = JSONElement(xpath, "value")
    e = {
        "old":json_element,
        "new":json_element
    }
    mocker.patch("diff_json.diffing.JSONDiff._get_shared_path_elements", return_value=e)
    json_diff = JSONDiff({"key":1}, {"key":2})
    json_diff.run()
    patch = json_diff.get_patch()
    assert patch
