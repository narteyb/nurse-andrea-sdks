import re

SLUG_PATTERN = re.compile(r"^[a-z][a-z0-9\-]{0,63}$")

SLUG_RULES_HUMAN = (
    "Workspace slugs must be lowercase letters, numbers, or hyphens. "
    "Must start with a letter. 1-64 characters."
)


def is_valid_slug(slug) -> bool:
    if not isinstance(slug, str) or not slug:
        return False
    return bool(SLUG_PATTERN.match(slug))
