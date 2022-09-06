def is_json_structure(value):
    return isinstance(value, (list, tuple, dict))


def sets_are_distinct(s1, s2):
    return (s1 & s2) == set()
