import os
import sys

SUPPORTED_ENVIRONMENTS = ("production", "staging", "development")

_warned = False


def detect_environment() -> str:
    raw = (
        os.environ.get("PYTHON_ENV")
        or os.environ.get("ENV")
        or os.environ.get("APP_ENV")
    )
    if not raw:
        return "production"

    if raw in SUPPORTED_ENVIRONMENTS:
        return raw

    _warn_once(raw)
    return "production"


def _warn_once(value: str) -> None:
    global _warned
    if _warned:
        return
    _warned = True
    sys.stderr.write(
        f"[NurseAndrea] Detected environment '{value}' is not in the "
        f"supported set {list(SUPPORTED_ENVIRONMENTS)}. "
        "Falling back to 'production'.\n"
    )


def _reset_warning() -> None:
    global _warned
    _warned = False
