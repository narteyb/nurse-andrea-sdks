from ..client import get_client
from ..configuration import is_enabled

class NurseAndreaStructlogProcessor:
    def __call__(self, logger, method, event_dict):
        if is_enabled():
            try:
                get_client().enqueue_log(
                    level=method if method in ("debug", "info", "warn", "error") else "info",
                    message=event_dict.get("event", ""),
                    metadata={k: v for k, v in event_dict.items() if k != "event"},
                )
            except Exception:
                pass
        return event_dict
