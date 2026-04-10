import re
import time
from ..client import get_client
from ..configuration import is_enabled, get_config

_NUMERIC_SEGMENT = re.compile(r"/\d+(?=/|$)")

def _normalise_path(path: str) -> str:
    return _NUMERIC_SEGMENT.sub("/:id", path) if path else "/"

class NurseAndreaDjangoMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if not is_enabled():
            return self.get_response(request)
        started_at = time.monotonic()
        response = self.get_response(request)
        duration_ms = (time.monotonic() - started_at) * 1000
        # Prefer the matched URL pattern, fall back to numeric normalisation.
        route = None
        match = getattr(request, "resolver_match", None)
        if match is not None and getattr(match, "route", None):
            route = "/" + match.route.lstrip("^").rstrip("$")
        if not route:
            route = _normalise_path(request.path)
        get_client().enqueue_metric(
            name="http.server.duration", value=round(duration_ms, 1), unit="ms",
            tags={"http_method": request.method, "http_path": route,
                  "http_status": str(response.status_code),
                  "service": get_config().service_name},
        )
        if response.status_code >= 400:
            get_client().enqueue_log(
                level="error" if response.status_code >= 500 else "warn",
                message=f"{request.method} {route} → {response.status_code} ({duration_ms:.1f}ms)",
            )
        return response
