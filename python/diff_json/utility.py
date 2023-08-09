from contextlib import contextmanager
import logging
import time


@contextmanager
def time_operation(label):
    logger = logging.getLogger("diff_json")
    start_time = time.time()

    try:
        yield start_time
    finally:
        end_time = time.time()
        ex_time = start_time - end_time
        logger.debug(f"{label} Execution Time: {round(ex_time, 6):.6f}s")


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
