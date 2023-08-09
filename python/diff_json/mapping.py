from abc import ABC
from functools import total_ordering
import json
import logging
from .utility import is_json_structure, py_to_json_type
from .exceptions import InvalidJSONDocument, JSONStructureError


logger = logging.getLogger("diff_json")


class Path(ABC):
    __slots__ = ["id", "segments", "path", "hash"]

    def __init__(self, path_segments):
        self.segments = path_segments
        self.path = self.__get_path_string(self.segments)
        self.hash = hash(self.path)

    def __hash__(self):
        return self.hash

    def __len__(self):
        return len(self.segments)

    @classmethod
    def path_string_to_segments(cls, path_string):
        return list(map(lambda x: int(x) if x.isdigit() else x, path_string.removeprefix("/").split("/")))

    @staticmethod
    def __get_path_string(segments):
        if len(segments) == 0:
            return ""

        return "/" + "/".join(list(map(str, segments)))


@total_ordering
class XPath(Path):
    def __init__(self, path_segments):
        super().__init__(path_segments)
        self.id = self.__build_id()

    # Required to explicity set the __hash__ method on any class that defines the __eq__ method.
    # It will not implicitly inherit the parent class's __hash__ method
    __hash__ = Path.__hash__

    def __str__(self):
        return self.path

    def __eq__(self, other):
        return self.id == other.id

    def __lt__(self, other):
        return self.id < other.id

    @classmethod
    def from_path_string(cls, path_string):
        return cls(cls.path_string_to_segments(path_string))

    def descend(self, next_segment):
        if type(next_segment) not in {int, str}:
            raise TypeError("You attempted to pass a segment of invalid type. XPath segments must"
                            "be integers or strings")

        descent_path = self.segments.copy()
        descent_path.append(next_segment)

        return XPath(descent_path)

    def to_match(self, wildcard=None):
        return XPathMatch(self.segments, wildcard or "")

    def __build_id(self):
        segment_keys = []

        for segment in self.segments:
            if type(segment) == int:
                segment_keys.append(f"i-{segment:04x}")
            else:
                segment_keys.append(f"s-{segment}")

        return "|".join(segment_keys)


class XPathMatch(Path):
    __slots__ = ["wildcard"]

    def __init__(self, path_segments, wildcard=None):
        super().__init__(path_segments)
        self.wildcard = wildcard or ''
        self.id = self.__build_id()

    def __str__(self):
        return f"{self.path}/{self.wildcard}"

    @classmethod
    def from_path_string(cls, path_string):
        segments = cls.path_string_to_segments(path_string)

        if segments[-1] in ("*", "**"):
            return cls(segments[0:-1], segments[-1])
        else:
            return cls(segments)

    def matches_path(self, xpath):
        if self.segments == xpath.segments[0:len(self)]:
            remainder = xpath.segments[len(self):]

            if self.wildcard in ('', None):
                return len(remainder) == 0
            elif self.wildcard == "*":
                return len(remainder) == 1
            elif self.wildcard == "**":
                return True

        return False

    def find_matches(self, xpaths):
        return [xpath for xpath in xpaths if self.matches_path(xpath)]

    def __build_id(self):
        segment_keys = []

        for segment in self.segments:
            if type(segment) == int:
                segment_keys.append(f"i-{segment:04x}")
            else:
                segment_keys.append(f"s-{segment}")

        base_key = "|".join(segment_keys)

        return f"{base_key}|{self.wildcard}" if self.wildcard else base_key


class MWXPM(Path):
    __slots__ = ["xpmr"]

    def __init__(self, path_segments):
        super().__init__(path_segments)
        self.xpmr = range(len(path_segments))
        self.id = self.__build_id()

    def matches_path(self, xpath):
        if self.segments == xpath.segments:
            return True

        if len(self.segments) > len(xpath.segments):
            return False
        else:
            segment_counts_match = len(self.xpmr) == len(xpath.segments)

        xpr = range(len(xpath))

        for ci in self.xpmr:
            is_last_index = (ci + 1) == len(self.xpmr)

            if self.segments[ci] == "*":
                if is_last_index:
                    return segment_counts_match
                else:
                    next_key = self.segments[ci + 1]

                    if next_key != xpath.segments[ci + 1]:
                        return False
            elif self.segments[ci] == "**":
                if is_last_index:
                    return True
                else:
                    next_key = self.segments[ci + 1]

                    if next_key not in xpath.segments[(ci + 1):]:
                        return False

                    
            else:
                if self.segments[ci] == xpath.segments[ci]:
                    ci += 1

                    if ci == len(xpr):
                        return True
                else:
                    return False

    def find_matches(self, xpaths):
        return [xpath for xpath in xpaths if self.matches_path(xpath)]

    def __build_id(self):
        segment_keys = []

        for segment in self.segments:
            if type(segment) == int:
                segment_keys.append(f"i-{segment:04x}")
            else:
                segment_keys.append(f"s-{segment}")

        return "|".join(segment_keys)


class JSONElement:
    __slots__ = ["id", "xpath", "json_type", "value", "value_hash", "length", "array_type", "object_keys", "index",
                 "key", "indentation", "trailing_comma"]

    def __init__(self, xpath, value, array_index=None, object_key=None, trailing_comma=False):
        self.xpath = xpath
        self.value = value
        self.json_type = py_to_json_type(self.value)

        if self.json_type is None:
            raise TypeError(f"The value provided is not of a JSON compatible type: {type(self.value)}."
                            "Allowed types are: list, tuple, dict, str, int, float, bool, and None.")

        self.value_hash = self.__hash_value()
        self.id = f"{self.xpath.id}|{self.value_hash:016x}"
        self.length = 0 if self.json_type == "primitive" else len(self.value)
        self.array_type = self.__get_array_type(self.json_type, self.value)
        self.object_keys = self.__get_object_keys(self.json_type, self.value)
        self.index = array_index or 0
        self.key = object_key
        self.indentation = len(self.xpath)
        self.trailing_comma = trailing_comma

    def __str__(self):
        return f"<JSONElement {self.id} || {self.json_type}>"

    def __hash__(self):
        return hash(self.id)

    def __eq__(self, other):
        return self.id == other.id

    def __lt__(self, other):
        return self.id < other.id

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

    @staticmethod
    def __get_object_keys(json_type, value):
        if json_type != "object":
            return tuple()

        return tuple(sorted(value.keys()))


class JSONMap:
    def __init__(self, json_document):
        if isinstance(json_document, str):
            try:
                json_document = json.loads(json_document)
            except json.JSONDecodeError:
                raise InvalidJSONDocument("A JSON string was passed to be mapped, but it could not be decoded")

        if not is_json_structure(json_document):
            raise JSONStructureError("JSON value to be mapped must be a structure (array/object)")

        logger.debug(f"Document Root Length: {len(json_document)}")
        self.map = {}
        self.map_element(json_document, XPath([]))

    def __str__(self):
        return f"<JSONMap {self.map[0].value_hash} || {len(self.map) - 1} element(s)>"

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
            key_range = range(len(json_element.object_keys))
            i = 0

            for current_key in json_element.object_keys:
                key_xpath = xpath.descend(current_key)
                self.map_element(json_element.value[current_key], key_xpath, key=current_key,
                                 trailing_comma=((i + 1) in key_range))
                i = i + 1

    def xpaths(self):
        return self.map.keys()

    def get_elements(self, xpaths):
        elements = []

        for xpath in xpaths:
            if xpath in self.map:
                elements.append(self.map[xpath])

        return elements
