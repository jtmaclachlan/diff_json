from contextlib import contextmanager
import logging
import time


@contextmanager
def time_operation(label):
    try:
        logger = logging.getLogger("diff_json")
        start_time = time.time()
        yield start_time
    finally:
        end_time = time.time()
        ex_time = start_time - end_time
        logger.debug(f"{label} Execution Time: {round((end_time - start_time), 6):.6f}s")
