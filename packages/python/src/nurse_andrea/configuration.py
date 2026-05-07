from __future__ import annotations
import os
import sys
from dataclasses import dataclass
from typing import Optional

from .errors import ConfigurationError, MigrationError
from .slug_validator import is_valid_slug, SLUG_RULES_HUMAN
from .environment_detector import detect_environment, SUPPORTED_ENVIRONMENTS

DEFAULT_HOST = "https://nurseandrea.io"
SDK_VERSION  = "1.0.0"
SDK_LANGUAGE = "python"

LEGACY_FIELDS = ("token", "api_key", "ingest_token")


def _migration_message(field: str) -> str:
    return (
        f"{field} is no longer supported in NurseAndrea SDK 1.0. "
        "Migrate to org_token + workspace_slug + environment. "
        "See https://docs.nurseandrea.io/sdk/migration"
    )


@dataclass
class NurseAndreaConfig:
    org_token: str = ""
    workspace_slug: str = ""
    environment: str = ""
    host: str = DEFAULT_HOST
    service_name: str = ""
    enabled: bool = True
    log_level: str = "warn"
    flush_interval_seconds: float = 5.0
    batch_size: int = 100

    def __post_init__(self):
        if not self.org_token:
            self.org_token = os.environ.get("NURSE_ANDREA_ORG_TOKEN", "")
        if self.host == DEFAULT_HOST:
            self.host = os.environ.get("NURSE_ANDREA_HOST", DEFAULT_HOST)
        if not self.environment:
            self.environment = detect_environment()
        if not self.service_name:
            self.service_name = (
                os.environ.get("RAILWAY_SERVICE_NAME")
                or os.environ.get("NURSE_ANDREA_SERVICE_NAME")
                or "python-app"
            )

    @property
    def ingest_url(self) -> str:
        return f"{self.host.rstrip('/')}/api/v1/ingest"

    @property
    def metrics_url(self) -> str:
        return f"{self.host.rstrip('/')}/api/v1/metrics"

    def is_valid(self) -> bool:
        return (
            bool(self.org_token)
            and bool(self.workspace_slug)
            and self.environment in SUPPORTED_ENVIRONMENTS
            and is_valid_slug(self.workspace_slug)
            and bool(self.host)
        )

    def validate(self) -> "NurseAndreaConfig":
        if not self.org_token:
            raise ConfigurationError("org_token is required")
        if not self.workspace_slug:
            raise ConfigurationError("workspace_slug is required")
        if not self.environment:
            raise ConfigurationError("environment is required")
        if self.environment not in SUPPORTED_ENVIRONMENTS:
            raise ConfigurationError(
                f"environment must be one of {', '.join(SUPPORTED_ENVIRONMENTS)} "
                f"(got {self.environment!r})"
            )
        if not is_valid_slug(self.workspace_slug):
            raise ConfigurationError(
                f"workspace_slug {self.workspace_slug!r} is invalid. {SLUG_RULES_HUMAN}"
            )
        return self


_config: Optional[NurseAndreaConfig] = None
_banner_printed: bool = False


def configure(**kwargs) -> NurseAndreaConfig:
    global _config, _banner_printed

    for legacy in LEGACY_FIELDS:
        if legacy in kwargs:
            raise MigrationError(_migration_message(legacy))

    _config = NurseAndreaConfig(**kwargs)
    _config.validate()

    # Defer imports to avoid circular dependencies.
    from .client import get_client
    get_client().start()

    from .tracing import start_trace_exporter
    start_trace_exporter()

    if not _banner_printed:
        _banner_printed = True
        sys.stdout.write(
            f"[NurseAndrea] Shipping to {_config.host} as {_config.service_name} "
            f"({SDK_LANGUAGE} sdk v{SDK_VERSION}, "
            f"workspace={_config.workspace_slug}/{_config.environment})\n"
        )
        sys.stdout.flush()

        import atexit
        atexit.register(get_client().stop)

    return _config


def get_config() -> NurseAndreaConfig:
    if _config is None:
        raise ConfigurationError(
            "NurseAndrea is not configured. Call configure(org_token=..., "
            "workspace_slug=..., environment=...) at startup."
        )
    return _config


def is_enabled() -> bool:
    return _config is not None and _config.enabled and _config.is_valid()


def _reset_for_tests() -> None:
    global _config, _banner_printed
    _config = None
    _banner_printed = False
