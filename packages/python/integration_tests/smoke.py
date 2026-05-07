#!/usr/bin/env python3
"""Smoke test for the NurseAndrea Python SDK 1.0 against a running NA instance.

Usage:
    LOCAL_ORG_TOKEN=org_xxx \\
      LOCAL_WORKSPACE_SLUG=somfo \\
      .venv/bin/python integration_tests/smoke.py

Optional:
    LOCAL_NA_HOST (default: http://localhost:4500)

Exits 0 on success, non-zero on failure.
"""
import os
import sys
import time
import httpx

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

from nurse_andrea.configuration import configure, SDK_VERSION, SDK_LANGUAGE
from nurse_andrea.client import get_client


def main() -> int:
    org_token = os.environ.get("LOCAL_ORG_TOKEN")
    if not org_token:
        sys.stderr.write("LOCAL_ORG_TOKEN is required.\n")
        return 2

    host = os.environ.get("LOCAL_NA_HOST", "http://localhost:4500")
    slug = os.environ.get("LOCAL_WORKSPACE_SLUG", "smoke-test-python")

    print(f"[smoke] Configuring NurseAndrea SDK {SDK_LANGUAGE} {SDK_VERSION}")
    print(f"[smoke]   host:           {host}")
    print(f"[smoke]   workspace_slug: {slug}")
    print(f"[smoke]   environment:    development")

    configure(
        org_token=org_token,
        workspace_slug=slug,
        environment="development",
        host=host,
        enabled=True,
        flush_interval_seconds=60,
        batch_size=1,
    )

    print("[smoke] Posting 5 ingest payloads via httpx with SDK headers...")
    headers = get_client().build_headers()

    success = 0
    with httpx.Client(timeout=10.0) as http:
        for i in range(5):
            r = http.post(
                f"{host}/api/v1/ingest",
                headers=headers,
                json={
                    "services":     ["smoke-test-python"],
                    "sdk_version":  SDK_VERSION,
                    "sdk_language": SDK_LANGUAGE,
                    "logs": [{
                        "level":       "info",
                        "message":     f"smoke test #{i}",
                        "occurred_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                        "source":      "smoke-test-python",
                        "payload":     {"iteration": i, "python_version": sys.version.split()[0]},
                    }],
                },
            )
            if 200 <= r.status_code < 300:
                success += 1
                sys.stdout.write(".")
            else:
                sys.stdout.write(f"x({r.status_code})")
            sys.stdout.flush()

    print()
    if success == 5:
        print("[smoke] OK — all 5 events accepted.")
        get_client().stop()
        return 0
    else:
        print(f"[smoke] FAIL — only {success}/5 events accepted.")
        get_client().stop()
        return 1


if __name__ == "__main__":
    sys.exit(main())
