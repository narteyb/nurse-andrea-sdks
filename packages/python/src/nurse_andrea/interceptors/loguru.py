from ..client import get_client
from ..configuration import is_enabled

LEVEL_MAP = {
    "TRACE": "debug", "DEBUG": "debug", "INFO": "info",
    "SUCCESS": "info", "WARNING": "warn", "ERROR": "error",
    "CRITICAL": "error",
}

def nurse_andrea_loguru_sink(message):
    if not is_enabled():
        return
    try:
        record = message.record
        get_client().enqueue_log(
            level=LEVEL_MAP.get(record["level"].name, "info"),
            message=record["message"],
            metadata={"logger": record["name"], "function": record["function"]},
        )
    except Exception:
        pass
