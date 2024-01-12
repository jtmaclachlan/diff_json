from diff_json.op_timer import time_operation

def test_time_operation():
    with time_operation("some_label") as start_time:
        assert start_time
