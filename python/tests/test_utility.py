from diff_json.utility import py_to_json_type, sets_are_distinct

def test_py_to_json_type_none_for_set():
    assert py_to_json_type(set()) == None

def test_sets_are_distinct_empty():
    assert sets_are_distinct(set(), set())

def test_sets_are_distinct_unique():
    set1 = {"one"}
    set2 = {"two"}
    assert sets_are_distinct(set1, set2)

def test_sets_are_distinct_not_unique():
    set1 = {"one"}
    set2 = {"one"}
    assert not sets_are_distinct(set1, set2)
