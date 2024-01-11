from abc import ABC
from functools import total_ordering


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
