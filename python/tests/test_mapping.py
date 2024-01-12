import pytest

from diff_json.mapping import JSONElement, JSONMap
from diff_json.pathfinding import XPath
from diff_json.exceptions import InvalidJSONDocument, JSONStructureError

def test_json_element_incompatible_json_type(mocker):
    mocker.patch("diff_json.mapping.py_to_json_type", return_value=None)
    xpath = XPath("key")
    with pytest.raises(TypeError):
        JSONElement(xpath, "value")

def test_str():
    xpath = XPath("key")
    json_element = JSONElement(xpath, "value")
    s = str(json_element)
    assert s

def test_mixed_array():
    xpath = XPath("key")
    json_element = JSONElement(xpath, [(1), [2], {"3":3}])
    assert json_element

def test_json_map_invalid_document_str():
    with pytest.raises(InvalidJSONDocument):
        JSONMap("{")

def test_json_map_invalid_document_bad_type():
    with pytest.raises(JSONStructureError):
        JSONMap(False)

def test_json_map_str():
    json_map = JSONMap('{"key":"value"}')
    s = str(json_map)
    assert s

def test_json_map_get_item_not_found():
    json_map = JSONMap('{"key":"value"}')
    s = json_map["something_weird"]
    assert s == None
