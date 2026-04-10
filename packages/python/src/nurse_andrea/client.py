from __future__ import annotations
import sys
import threading
import time
from dataclasses import dataclass, field
from typing import Optional
import httpx
from .configuration import get_config, is_enabled

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

class NurseAndreaClient:
    def __init__(self):
        self._log_queue: list[LogEntry] = []
        self._metric_queue: list[MetricEntry] = []
        self._lock = threading.Lock()
        self._timer: Optional[threading.Timer] = None
        self._started = False

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
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {config.token}",
        }

        try:
            with httpx.Client(timeout=10.0) as http:
                if logs:
                    r = http.post(config.ingest_url, json={
                        "sdk_version": "0.1.8", "sdk_language": "python",
                        "logs": [{"level": e.level, "message": e.message,
                                  "occurred_at": e.timestamp, "source": e.service,
                                  "metadata": e.metadata} for e in logs]
                    }, headers=headers)
                    if r.status_code >= 400:
                        sys.stderr.write(f"[NurseAndrea] POST {config.ingest_url} → {r.status_code}: {r.text[:200]}\n")
                if metrics:
                    r = http.post(config.metrics_url, json={
                        "sdk_version": "0.1.8", "sdk_language": "python",
                        "metrics": [{"name": e.name, "value": e.value,
                                     "unit": e.unit, "occurred_at": e.timestamp,
                                     "tags": e.tags} for e in metrics]
                    }, headers=headers)
                    if r.status_code >= 400:
                        sys.stderr.write(f"[NurseAndrea] POST {config.metrics_url} → {r.status_code}: {r.text[:200]}\n")
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
        # macOS: ru_maxrss is bytes
        return _resource.getrusage(_resource.RUSAGE_SELF).ru_maxrss
    except Exception:
        return None

def _iso_now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%S.000Z", time.gmtime())

_client = NurseAndreaClient()
def get_client() -> NurseAndreaClient:
    return _client
