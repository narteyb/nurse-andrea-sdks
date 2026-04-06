import pytest
from unittest.mock import patch
from nurse_andrea.configuration import configure
from nurse_andrea.client import get_client

def test_flask_middleware_enqueues_metric():
    from flask import Flask
    configure(token="test", enabled=True, flush_interval_seconds=9999)
    app = Flask(__name__)

    from nurse_andrea.middleware.flask import init_app
    init_app(app)

    @app.route("/ping")
    def ping():
        return "ok"

    with patch.object(get_client(), "enqueue_metric") as mock_metric:
        with app.test_client() as client:
            client.get("/ping")
        mock_metric.assert_called_once()
        assert mock_metric.call_args.kwargs["name"] == "http.server.duration"
