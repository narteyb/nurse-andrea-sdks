import time
from ..client import get_client
from ..configuration import is_enabled, get_config

def init_app(app):
    @app.before_request
    def _before():
        from flask import g
        if is_enabled():
            g._nurse_andrea_start = time.monotonic()

    @app.after_request
    def _after(response):
        from flask import g, request
        if not is_enabled():
            return response
        start = getattr(g, "_nurse_andrea_start", None)
        if start is None:
            return response
        duration_ms = (time.monotonic() - start) * 1000
        route = request.url_rule.rule if request.url_rule else request.path
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
