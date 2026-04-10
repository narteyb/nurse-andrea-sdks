"""Lightweight trace exporter — ships spans in OTLP JSON format."""
import json
import os
import sys
import threading
import time
import uuid
from .configuration import get_config, is_enabled

_queue: list[dict] = []
_lock = threading.Lock()
_timer: threading.Timer | None = None
_started = False

BATCH_SIZE = 100
FLUSH_INTERVAL = 5.0


def generate_trace_id() -> str:
    return uuid.uuid4().hex


def generate_span_id() -> str:
    return uuid.uuid4().hex[:16]


def enqueue_span(span: dict) -> None:
    if not is_enabled():
        return
    with _lock:
        _queue.append(span)
        if len(_queue) >= BATCH_SIZE:
            threading.Thread(target=_flush, daemon=True).start()


def start_trace_exporter() -> None:
    global _started
    if _started:
        return
    _started = True
    _schedule_flush()


def _schedule_flush() -> None:
    global _timer
    _timer = threading.Timer(FLUSH_INTERVAL, _scheduled_flush)
    _timer.daemon = True
    _timer.start()


def _scheduled_flush() -> None:
    _flush()
    if _started:
        _schedule_flush()


def _flush() -> None:
    with _lock:
        if not _queue:
            return
        spans = _queue[:]
        _queue.clear()

    config = get_config()
    payload = {
        "resourceSpans": [{
            "resource": {
                "attributes": [
                    {"key": "service.name", "value": {"stringValue": config.service_name}}
                ]
            },
            "scopeSpans": [{"spans": spans}]
        }]
    }

    url = f"{config.host.rstrip('/')}/api/v1/traces"
    try:
        import httpx
        with httpx.Client(timeout=5.0) as http:
            r = http.post(url, json=payload, headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {config.token}",
            })
            if r.status_code >= 400:
                sys.stderr.write(f"[NurseAndrea] Trace export → {r.status_code}\n")
    except Exception as e:
        sys.stderr.write(f"[NurseAndrea] Trace export failed: {e}\n")


def make_server_span(method: str, path: str, status_code: int,
                     start_ns: int, end_ns: int, service_name: str) -> dict:
    """Build an OTLP-format span dict for a server request."""
    return {
        "traceId": generate_trace_id(),
        "spanId": generate_span_id(),
        "parentSpanId": "",
        "name": f"{method} {path}",
        "kind": 2,
        "startTimeUnixNano": str(start_ns),
        "endTimeUnixNano": str(end_ns),
        "status": {
            "code": 2 if status_code >= 500 else 1,
            "message": f"HTTP {status_code}" if status_code >= 500 else "",
        },
        "attributes": [
            {"key": "http.method", "value": {"stringValue": method}},
            {"key": "http.url", "value": {"stringValue": path}},
            {"key": "http.status_code", "value": {"intValue": status_code}},
        ],
        "events": [],
    }
