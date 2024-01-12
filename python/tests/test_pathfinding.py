import pytest

from diff_json.pathfinding import XPath, XPathMatch

def test_xpath_from_path_string():
    xpath = XPath("something")
    assert str(xpath.from_path_string("whatever")) == "/whatever"

def test_descend_error():
    xpath = XPath("something")
    with pytest.raises(TypeError):
        xpath.descend(True)

def test_xpath_match_str():
    xpath_match = XPathMatch(["key"])
    assert str(xpath_match)

def test_xpath_match_not_matches_path_with_weird_wildcard():
    xpath_match = XPathMatch(["**"], "***")
    xpath = XPath(["**"])
    assert not xpath_match.matches_path(xpath)
