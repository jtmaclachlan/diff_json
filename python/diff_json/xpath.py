from abc import ABC
from functools import total_ordering
from .exceptions import InvalidXPathSegmentError


class Path(ABC):
    __slots__ = ["segments", "path", "hash"]

    def __init__(self, path_segments):
        self.segments = path_segments
        self.path = self.__get_path_string(self.segments)
        self.hash = hash(self.path)

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
    __slots__ = ["sort_key"]

    def __init__(self, path_segments):
        super().__init__(path_segments)
        self.sort_key = self.__build_sort_key(self.segments)

    def __hash__(self):
        return self.hash

    def __str__(self):
        return self.path

    def __len__(self):
        return len(self.segments)

    def __eq__(self, other):
        return self.sort_key == other.sort_key

    def __lt__(self, other):
        return self.sort_key < other.sort_key

    def descend(self, next_segment):
        if type(next_segment) not in {int, str}:
            raise InvalidXPathSegmentError("You attempted to pass a segment of invalid type. XPath segments must integers or strings")

        descent_path = self.segments.copy()
        descent_path.append(next_segment)

        return XPath(descent_path)

    @staticmethod
    def __build_sort_key(segments):
        segment_keys = []

        for segment in segments:
            if type(segment) == int:
                segment_keys.append(f"i-{segment:04x}")
            else:
                segment_keys.append(f"s-{segment}")

        return "|".join(segment_keys)


class XPathMatch(Path):
    __slots__ = ["slice_length", "wildcard"]

    def __init__(self, path_segments, wildcard=None):
        super().__init__(path_segments)
        self.slice_length = len(self.segments)
        self.wildcard = wildcard or ''

    def __hash__(self):
        return self.hash

    def __str__(self):
        return f"{self.path}/{self.wildcard}"

    def __len__(self):
        return len(self.segments)

    @classmethod
    def from_path_string(cls, path_string):
        segments = cls.path_string_to_segments(path_string)

        if segments[-1] in ("*", "**"):
            return cls(segments[0:-1], segments[-1])
        else:
            return cls(segments)

    def matches(self, xpath):
        if self.segments == xpath.segments[0:self.slice_length]:
            remainder = xpath.segments[self.slice_length:]

            if self.wildcard in ('', None):
                return len(remainder) == 0
            elif self.wildcard == "*":
                return len(remainder) in range(1)
            elif self.wildcard == "**":
                return True

        return False
