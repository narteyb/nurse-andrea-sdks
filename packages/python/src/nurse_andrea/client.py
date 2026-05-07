from __future__ import annotations
import json
import sys
import threading
import time
from dataclasses import dataclass, field
from typing import Optional
import httpx

from .configuration import (
    get_config,
    is_enabled,
    SDK_VERSION,
    SDK_LANGUAGE,
)
from .slug_validator import SLUG_RULES_HUMAN

REJECTION_WARNING_THRESHOLD = 5
REJECTION_STATUSES = {401, 403, 422, 429}


@dataclass
class LogEntry:
    level: str
    message: str
    timestamp: str
    service: str
    metadata: dict = field(default_factory=dict)


@dataclass
class MetricEntry:
    name: str
    value: float
    unit: str
    timestamp: str
    tags: dict = field(default_factory=dict)


def _guidance_for(error_code: str, environment: str, host: str) -> str:
    return {
        "invalid_org_token":                       "Check NURSE_ANDREA_ORG_TOKEN.",
        "workspace_rejected":                      "Restore the workspace in the dashboard or change workspace_slug.",
        "workspace_limit_exceeded":                "Org has reached its workspace limit. Reject unused workspaces or upgrade plan.",
        "auto_create_disabled":                    "Auto-create disabled. Create the workspace explicitly in the dashboard before ingesting.",
        "environment_not_accepted_by_this_install": (
            f"Environment '{environment}' not accepted by NurseAndrea at {host}. Check NURSE_ANDREA_HOST."
        ),
        "invalid_workspace_slug":                  SLUG_RULES_HUMAN,
        "similar_slug_exists":                     "A similar slug already exists in this org. Did you mean an existing one?",
        "creation_rate_limit_exceeded":            "Workspace creation rate limit hit. Existing workspaces still ingesting normally.",
        "rate_limited":                            "Workspace creation rate limit hit. Existing workspaces still ingesting normally.",
    }.get(error_code, "")


class NurseAndreaClient:
    def __init__(self):
        self._log_queue: list[LogEntry] = []
        self._metric_queue: list[MetricEntry] = []
        self._lock = threading.Lock()
        self._timer: Optional[threading.Timer] = None
        self._started = False

        self._consecutive_rejections = 0
        self._warned_for_error: Optional[str] = None
        self._rejection_lock = threading.Lock()

    def start(self):
        if self._started or not is_enabled():
            return
        self._started = True
        self._schedule_flush()

    def stop(self):
        if self._timer:
            self._timer.cancel()
            self._timer = None
        self._flush_sync()

    def reset_rejection_state(self) -> None:
        with self._rejection_lock:
            self._consecutive_rejections = 0
            self._warned_for_error = None

    def build_headers(self) -> dict:
        config = get_config()
        return {
            "Content-Type":              "application/json",
            "Authorization":             f"Bearer {config.org_token}",
            "X-NurseAndrea-Workspace":   config.workspace_slug,
            "X-NurseAndrea-Environment": config.environment,
            "X-NurseAndrea-SDK":         f"{SDK_LANGUAGE}/{SDK_VERSION}",
        }

    def handle_response(self, status_code: int, body_text: str, url: str) -> None:
        if 200 <= status_code < 300:
            with self._rejection_lock:
                self._consecutive_rejections = 0
                self._warned_for_error = None
            return

        if status_code not in REJECTION_STATUSES:
            sys.stderr.write(f"[NurseAndrea] POST {url} -> {status_code}\n")
            return

        with self._rejection_lock:
            self._consecutive_rejections += 1
            if self._consecutive_rejections < REJECTION_WARNING_THRESHOLD:
                return

            try:
                body = json.loads(body_text) if body_text else {}
            except (ValueError, TypeError):
                body = {}
            error_code = body.get("error", "") if isinstance(body, dict) else ""
            if self._warned_for_error == error_code:
                return
            self._warned_for_error = error_code

            config = get_config()
            message = body.get("message", "") if isinstance(body, dict) else ""
            details = f" Details: {message}" if message else ""
            sys.stderr.write(
                f"[NurseAndrea] Ingest rejected ({REJECTION_WARNING_THRESHOLD}+ consecutive). "
                f"Status: {status_code} Error: {error_code or '(unknown)'}. "
                f"{_guidance_for(error_code, config.environment, config.host)}"
                f"{details}\n"
            )

    def enqueue_log(self, level: str, message: str, metadata: dict = None):
        if not is_enabled():
            return
        config = get_config()
        entry = LogEntry(
            level=level, message=message,
            timestamp=_iso_now(), service=config.service_name,
            metadata=metadata or {},
        )
        with self._lock:
            self._log_queue.append(entry)
            if len(self._log_queue) >= config.batch_size:
                self._flush_async()

    def enqueue_metric(self, name: str, value: float, unit: str, tags: dict = None):
        if not is_enabled():
            return
        config = get_config()
        entry = MetricEntry(
            name=name, value=value, unit=unit,
            timestamp=_iso_now(),
            tags={"service": config.service_name, **(tags or {})},
        )
        with self._lock:
            self._metric_queue.append(entry)
            if len(self._metric_queue) >= config.batch_size:
                self._flush_async()

    def _schedule_flush(self):
        interval = get_config().flush_interval_seconds
        self._timer = threading.Timer(interval, self._scheduled_flush)
        self._timer.daemon = True
        self._timer.start()

    def _scheduled_flush(self):
        self._collect_process_memory()
        self._flush_sync()
        if self._started:
            self._schedule_flush()

    def _collect_process_memory(self):
        try:
            rss = _get_rss_bytes()
            if rss and rss > 0:
                self.enqueue_metric(
                    name="process.memory.rss", value=float(rss),
                    unit="bytes", tags={"service": get_config().service_name},
                )
        except Exception:
            pass

    def _flush_async(self):
        threading.Thread(target=self._flush_sync, daemon=True).start()

    def _flush_sync(self):
        with self._lock:
            logs = self._log_queue[:]
            metrics = self._metric_queue[:]
            self._log_queue.clear()
            self._metric_queue.clear()

        if not logs and not metrics:
            return

        config = get_config()
        headers = self.build_headers()

        try:
            with httpx.Client(timeout=10.0) as http:
                if logs:
                    r = http.post(config.ingest_url, json={
                        "services":     [config.service_name],
                        "sdk_version":  SDK_VERSION,
                        "sdk_language": SDK_LANGUAGE,
                        "logs": [{
                            "level":       e.level,
                            "message":     e.message,
                            "occurred_at": e.timestamp,
                            "source":      e.service,
                            "payload":     e.metadata,
                        } for e in logs]
                    }, headers=headers)
                    self.handle_response(r.status_code, r.text, config.ingest_url)
                if metrics:
                    r = http.post(config.metrics_url, json={
                        "sdk_version":  SDK_VERSION,
                        "sdk_language": SDK_LANGUAGE,
                        "metrics": [{
                            "name":        e.name,
                            "value":       e.value,
                            "unit":        e.unit,
                            "occurred_at": e.timestamp,
                            "tags":        e.tags,
                        } for e in metrics]
                    }, headers=headers)
                    self.handle_response(r.status_code, r.text, config.metrics_url)
        except Exception as e:
            sys.stderr.write(f"[NurseAndrea] Flush failed: {type(e).__name__}: {e}\n")
            with self._lock:
                self._log_queue[:0] = logs
                self._metric_queue[:0] = metrics


def _get_rss_bytes() -> Optional[int]:
    try:
        import resource as _resource
        if sys.platform == "linux":
            with open("/proc/self/status") as f:
                for line in f:
                    if line.startswith("VmRSS:"):
                        return int(line.split()[1]) * 1024
        return _resource.getrusage(_resource.RUSAGE_SELF).ru_maxrss
    except Exception:
        return None


def _iso_now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%S.000Z", time.gmtime())


_client = NurseAndreaClient()


def get_client() -> NurseAndreaClient:
    return _client
