import pytest
from nurse_andrea.slug_validator import is_valid_slug


@pytest.mark.parametrize("slug,expected", [
    ("a", True),
    ("checkout-2", True),
    ("a1-b2-c3", True),
    ("a" + "b" * 63, True),
    (None, False),
    ("", False),
    ("1-checkout", False),
    ("-checkout", False),
    ("Checkout", False),
    ("check_out", False),
    ("check.out", False),
    ("check out", False),
    ("a" + "b" * 64, False),
])
def test_is_valid_slug(slug, expected):
    assert is_valid_slug(slug) is expected
