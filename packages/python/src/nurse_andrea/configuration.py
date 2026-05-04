from __future__ import annotations
import os
import sys
from dataclasses import dataclass
from typing import Optional

DEFAULT_HOST = "https://nurseandrea.io"
SDK_VERSION  = "0.2.1"

@dataclass
class NurseAndreaConfig:
    token: str = ""
    host: str = DEFAULT_HOST
    service_name: str = ""
    enabled: bool = True
    log_level: str = "warn"
    flush_interval_seconds: float = 5.0
    batch_size: int = 100

    def __post_init__(self):
        if not self.token:
            self.token = (
                os.getenv("NURSE_ANDREA_INGEST_TOKEN")
                or os.getenv("NURSE_ANDREA_TOKEN")
                or ""
            )
        if self.host == DEFAULT_HOST:
            self.host = os.getenv("NURSE_ANDREA_HOST", DEFAULT_HOST)
        if not self.service_name:
            self.service_name = (
                os.getenv("RAILWAY_SERVICE_NAME") or
                os.getenv("NURSE_ANDREA_SERVICE_NAME") or
                "python-app"
            )
        if not self.token:
            self.enabled = False

    @property
    def ingest_url(self) -> str:
        return f"{self.host.rstrip('/')}/api/v1/ingest"

    @property
    def metrics_url(self) -> str:
        return f"{self.host.rstrip('/')}/api/v1/metrics"

    def is_valid(self) -> bool:
        return bool(self.token and self.host)


_config: Optional[NurseAndreaConfig] = None
_banner_printed: bool = False

def configure(**kwargs) -> NurseAndreaConfig:
    global _config, _banner_printed
    _config = NurseAndreaConfig(**kwargs)

    if not _config.enabled or not _config.is_valid():
        sys.stderr.write(
            "[NurseAndrea] No token configured. "
            "Set NURSE_ANDREA_INGEST_TOKEN or pass token=... to configure(). "
            "Monitoring disabled.\n"
        )
        return _config

    # Defer import to avoid circular dependency (client imports from this module).
    from .client import get_client
    get_client().start()

    from .tracing import start_trace_exporter
    start_trace_exporter()

    if not _banner_printed:
        _banner_printed = True
        sys.stdout.write(
            f"[NurseAndrea] Shipping to {_config.host} as {_config.service_name} "
            f"(python sdk v{SDK_VERSION})\n"
        )
        sys.stdout.flush()

        import atexit
        atexit.register(get_client().stop)

    return _config

def get_config() -> NurseAndreaConfig:
    global _config
    if _config is None:
        _config = NurseAndreaConfig()
    return _config

def is_enabled() -> bool:
    return get_config().enabled and get_config().is_valid()
