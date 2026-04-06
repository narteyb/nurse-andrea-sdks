import logging
from ..client import get_client
from ..configuration import is_enabled

LEVEL_MAP = {
    logging.DEBUG: "debug", logging.INFO: "info",
    logging.WARNING: "warn", logging.ERROR: "error",
    logging.CRITICAL: "error",
}

class NurseAndreaHandler(logging.Handler):
    def emit(self, record):
        if not is_enabled():
            return
        try:
            get_client().enqueue_log(
                level=LEVEL_MAP.get(record.levelno, "info"),
                message=self.format(record),
                metadata={"logger": record.name, "module": record.module},
            )
        except Exception:
            self.handleError(record)

def intercept_root_logger(level=logging.WARNING):
    handler = NurseAndreaHandler()
    handler.setLevel(level)
    logging.getLogger().addHandler(handler)
    return handler
