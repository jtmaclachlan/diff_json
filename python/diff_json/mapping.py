import json
from ._util import is_json_structure
from .exceptions import InvalidJSONDocument, JSONStructureError
from .xpath import XPath


class JSONElement:
    __slots__ = ["value", "json_type", "hash", "length", "array_type", "array_hashes", "keys", "map_data"]

    def __init__(self, value, min_init=False):
        self.value = value
        self.json_type = self.__get_json_type(self.value)
        self.hash = hash(self)

        if not min_init:
            self.length = 0 if self.json_type == "primitive" else len(self.value)
            self.array_type = self.__get_array_type(self.json_type, self.value)
            self.array_hashes = self.__get_array_hashes(self.json_type, self.value)
            self.keys = self.__get_object_keys(self.json_type, self.value)
            self.map_data = {}

    def __str__(self):
        return f"{self.json_type} || {self.get_map_property('xpath')} || {self.hash}"

    def __hash__(self):
        if self.json_type == "primitive":
            return hash(self.value)
        else:
            return hash(json.dumps(self.value))

    def __eq__(self, other):
        return self.hash == other.hash

    def get_map_property(self, data_key):
        if data_key in self.map_data:
            return self.map_data[data_key]

        return None

    @staticmethod
    def __get_json_type(value):
        if isinstance(value, (list, tuple)):
            return "array"
        elif isinstance(value, dict):
            return "object"
        else:
            return "primitive"

    @staticmethod
    def __get_array_type(json_type, value):
        if json_type != "array":
            return None

        contained_types = list(set(map(is_json_structure, value)))

        if len(contained_types) == 0:
            return "empty"
        elif len(contained_types) > 1:
            return "mixed"
        else:
            return "structures" if contained_types[0] else "primitives"

    @staticmethod
    def __get_array_hashes(json_type, value):
        def get_sub_hash(arr_element_value):
            json_element = JSONElement(arr_element_value, True)
            sub_hash = json_element.hash
            del json_element

            return sub_hash

        if json_type != "array":
            return []

        return list(map(get_sub_hash, value))

    @staticmethod
    def __get_object_keys(json_type, value):
        if json_type != "object":
            return set()

        return set(value.keys())


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
        return f"JSONMap {self.map[0].get_meta_value('hash')} || {len(self.map)}"

    def __getitem__(self, item):
        if item in self.map:
            return self.map[item]
        else:
            return None

    def xpaths(self):
        return self.map.keys()

    def map_element(self, raw_element, xpath, index=0, key=None, trailing_comma=False):
        json_element = JSONElement(raw_element)
        json_element.map_data = {
            'index': index,
            'key': key,
            'indentation': len(xpath),
            'trailing_comma': trailing_comma
        }
        self.map[xpath] = json_element

        if json_element.json_type == "array":
            array_range = range(len(json_element.value))

            for i in array_range:
                index_xpath = xpath.descend(i)
                self.map_element(json_element.value[i], index_xpath, index=i, key=None,
                                 trailing_comma=((i + 1) in array_range))
        elif json_element.json_type == "object":
            sorted_keys = list(json_element.value.keys())
            sorted_keys.sort()
            key_range = range(len(sorted_keys))

            for i in key_range:
                current_key = sorted_keys[i]
                key_xpath = xpath.descend(current_key)
                self.map_element(json_element.value[current_key], key_xpath, index=i, key=current_key,
                                 trailing_comma=((i + 1) in key_range))
