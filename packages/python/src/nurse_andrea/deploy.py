"""Deploy event API.

Public: NurseAndrea.deploy(version=...) ships a deploy event to the
backend so the dashboard can render it as a vertical marker on
time-series charts and as a chip in the recent-deploys strip.

Fire-and-forget: any failure (no token, network error, non-2xx) is
logged to stderr and swallowed so the host application never crashes
from a deploy notification.
"""

from __future__ import annotations
import sys
from datetime import datetime, timezone
from typing import Optional

import httpx

from .configuration import get_config, is_enabled, SDK_LANGUAGE, SDK_VERSION

DESCRIPTION_LIMIT = 500


def deploy(
    version: str,
    deployer:    Optional[str] = None,
    environment: str           = "production",
    description: Optional[str] = None,
) -> bool:
    if not is_enabled():
        return False
    if not version or not str(version).strip():
        return False

    if isinstance(description, str) and len(description) > DESCRIPTION_LIMIT:
        description = description[:DESCRIPTION_LIMIT]

    payload = {
        "version":     str(version),
        "deployer":    deployer,
        "environment": environment,
        "description": description,
        "deployed_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    }

    config = get_config()
    url = f"{config.host.rstrip('/')}/api/v1/deploy"
    headers = {
        "Authorization":             f"Bearer {config.org_token}",
        "X-NurseAndrea-Workspace":   config.workspace_slug,
        "X-NurseAndrea-Environment": config.environment,
        # Sprint B D2 — added to align with the cross-runtime header
        # spec (docs/sdk/payload-format.md §5.2). Ruby's deploy went
        # through the shared HttpClient which already attached this;
        # Python/Node/Go's deploy paths were missing it.
        "X-NurseAndrea-SDK":         f"{SDK_LANGUAGE}/{SDK_VERSION}",
    }
    try:
        with httpx.Client(timeout=10.0) as http:
            r = http.post(url, json=payload, headers=headers)
        if 200 <= r.status_code < 300:
            return True
        sys.stderr.write(f"[NurseAndrea] deploy() POST {url} -> {r.status_code}\n")
        return False
    except Exception as e:
        sys.stderr.write(f"[NurseAndrea] deploy() error: {e.__class__.__name__}: {e}\n")
        return False
