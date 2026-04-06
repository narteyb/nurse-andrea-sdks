import time
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response
from ..client import get_client
from ..configuration import is_enabled, get_config

class NurseAndreaFastAPIMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        if not is_enabled():
            return await call_next(request)
        started_at = time.monotonic()
        response = await call_next(request)
        duration_ms = (time.monotonic() - started_at) * 1000
        route = request.url.path
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
