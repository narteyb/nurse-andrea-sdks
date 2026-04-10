import re
import time
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response
from ..tracing import enqueue_span, make_server_span
from ..client import get_client
from ..configuration import is_enabled, get_config

_NUMERIC_SEGMENT = re.compile(r"/\d+(?=/|$)")

def _normalise_path(path: str) -> str:
    return _NUMERIC_SEGMENT.sub("/:id", path) if path else "/"

class NurseAndreaFastAPIMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        if not is_enabled():
            return await call_next(request)
        started_at = time.monotonic()
        start_ns = int(time.time() * 1_000_000_000)
        response = await call_next(request)
        end_ns = int(time.time() * 1_000_000_000)
        duration_ms = (time.monotonic() - started_at) * 1000
        # Prefer the matched route template, fall back to numeric normalisation.
        route = None
        scope_route = request.scope.get("route")
        if scope_route is not None and getattr(scope_route, "path", None):
            route = scope_route.path
        if not route:
            route = _normalise_path(request.url.path)
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
        enqueue_span(make_server_span(
            request.method, route, response.status_code,
            start_ns, end_ns, get_config().service_name,
        ))
        return response
