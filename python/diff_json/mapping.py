import json
from ._util import is_json_structure, py_to_json_type
from .exceptions import InvalidJSONDocument, JSONStructureError
from .xpath import XPath


class JSONElement:
    __slots__ = ["eid", "xpath", "json_type", "value", "value_hash", "length", "array_type", "index", "key",
                 "indentation", "trailing_comma"]

    def __init__(self, xpath, value, array_index=None, object_key=None, trailing_comma=False):
        self.xpath = xpath
        self.value = value
        self.json_type = py_to_json_type(self.value)

        if self.json_type is None:
            raise TypeError(f"JSON mapping discovered a value of a non-JSON compatible type: {type(self.value)}")

        self.value_hash = self.__hash_value()
        self.eid = f"{self.xpath}|{self.value_hash:016x}"
        self.length = 0 if self.json_type == "primitive" else len(self.value)
        self.array_type = self.__get_array_type(self.json_type, self.value)
        self.index = array_index or 0
        self.key = object_key
        self.indentation = len(xpath)
        self.trailing_comma = trailing_comma

    def __str__(self):
        return f"<JSONElement {self.eid} || {self.json_type}>"

    def __hash__(self):
        return hash(self.eid)

    def __eq__(self, other):
        return self.eid == other.eid

    def __hash_value(self):
        if self.json_type == "primitive":
            return hash(self.value)
        else:
            return hash(json.dumps(self.value))

    @staticmethod
    def __get_array_type(json_type, value):
        if json_type != "array":
            return None

        contained_types = set(map(is_json_structure, value))

        if len(contained_types) == 0:
            return "empty"
        elif len(contained_types) > 1:
            return "mixed"
        else:
            return "structures" if True in contained_types else "primitives"


class JSONMap:
    def __init__(self, json_document):
        if isinstance(json_document, str):
            try:
                json_document = json.loads(json_document)
            except json.JSONDecodeError:
                raise InvalidJSONDocument("A JSON string was passed to be mapped, but it could not be decoded")

        if not is_json_structure(json_document):
            raise JSONStructureError("JSON value to be mapped must be a structure (array/object)")

        self.map = {}
        self.map_element(json_document, XPath([]))

    def __str__(self):
        return f"<JSONMap {self.map[0].value_hash} || {len(self.map) - 1} elements>"

    def __getitem__(self, item):
        if item in self.map:
            return self.map[item]
        else:
            return None

    def map_element(self, raw_element, xpath, index=0, key=None, trailing_comma=False):
        json_element = JSONElement(xpath, raw_element, array_index=index, object_key=key, trailing_comma=trailing_comma)
        self.map[xpath] = json_element

        if json_element.json_type == "array":
            array_range = range(len(json_element.value))

            for i in array_range:
                index_xpath = xpath.descend(i)
                self.map_element(json_element.value[i], index_xpath, index=i, trailing_comma=((i + 1) in array_range))
        elif json_element.json_type == "object":
            sorted_keys = list(json_element.value.keys())
            sorted_keys.sort()
            key_range = range(len(sorted_keys))

            for i in key_range:
                current_key = sorted_keys[i]
                key_xpath = xpath.descend(current_key)
                self.map_element(json_element.value[current_key], key_xpath, key=current_key,
                                 trailing_comma=((i + 1) in key_range))

    def xpaths(self):
        return self.map.keys()

    def get_elements(self, xpaths):
        elements = []

        for xpath in xpaths:
            if xpath in self.map:
                elements.append(self.map[xpath])

        return elements
