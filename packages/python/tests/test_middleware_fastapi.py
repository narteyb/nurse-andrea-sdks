import pytest
from unittest.mock import patch
from nurse_andrea.configuration import configure
from nurse_andrea.client import get_client

def test_fastapi_middleware_enqueues_metric():
    from fastapi import FastAPI
    from fastapi.testclient import TestClient
    from nurse_andrea.middleware.fastapi import NurseAndreaFastAPIMiddleware

    configure(token="test", enabled=True, flush_interval_seconds=9999)
    app = FastAPI()
    app.add_middleware(NurseAndreaFastAPIMiddleware)

    @app.get("/ping")
    def ping():
        return {"ok": True}

    with patch.object(get_client(), "enqueue_metric") as mock_metric:
        client = TestClient(app)
        client.get("/ping")
        mock_metric.assert_called_once()
        assert mock_metric.call_args.kwargs["name"] == "http.server.duration"
