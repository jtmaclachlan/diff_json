def is_json_structure(value):
    return isinstance(value, (list, tuple, dict))


def py_to_json_type(value):
    if isinstance(value, (list, tuple)):
        return "array"
    elif isinstance(value, dict):
        return "object"
    elif value is None or isinstance(value, (int, float, str, bool)):
        return "primitive"

    return None


def sets_are_distinct(s1, s2):
    return (s1 & s2) == set()
