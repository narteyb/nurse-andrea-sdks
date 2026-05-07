import pytest
from nurse_andrea.configuration import configure, _reset_for_tests
from nurse_andrea.client import get_client


def _valid_kwargs():
    return dict(
        org_token="org_test_token",
        workspace_slug="checkout",
        environment="development",
        host="http://localhost:4500",
        enabled=True,
        flush_interval_seconds=9999,
    )


@pytest.fixture(autouse=True)
def reset():
    _reset_for_tests()
    configure(**_valid_kwargs())
    get_client().reset_rejection_state()
    yield
    get_client().stop()
    _reset_for_tests()


def test_enqueues_log():
    get_client().enqueue_log(level="info", message="hello")
    assert len(get_client()._log_queue) >= 1


def test_enqueues_metric_with_service_tag():
    get_client().enqueue_metric(name="http.request.duration", value=42, unit="ms")
    metric = next((m for m in get_client()._metric_queue if m.value == 42), None)
    assert metric is not None
    assert "service" in metric.tags


def test_build_headers_emits_new_auth_contract():
    headers = get_client().build_headers()
    assert headers["Authorization"] == "Bearer org_test_token"
    assert headers["X-NurseAndrea-Workspace"] == "checkout"
    assert headers["X-NurseAndrea-Environment"] == "development"
    assert headers["X-NurseAndrea-SDK"] == "python/1.0.0"


class TestRejectionCounter:
    def test_silent_for_4_consecutive(self, capsys):
        for _ in range(4):
            get_client().handle_response(401, '{"error":"invalid_org_token"}', "u")
        assert "Ingest rejected" not in capsys.readouterr().err

    def test_warns_once_after_5(self, capsys):
        for _ in range(8):
            get_client().handle_response(401, '{"error":"invalid_org_token"}', "u")
        err = capsys.readouterr().err
        assert err.count("Ingest rejected") == 1
        assert "invalid_org_token" in err
        assert "Check NURSE_ANDREA_ORG_TOKEN" in err

    def test_resets_on_success(self, capsys):
        for _ in range(4):
            get_client().handle_response(401, '{"error":"invalid_org_token"}', "u")
        get_client().handle_response(200, "{}", "u")
        for _ in range(4):
            get_client().handle_response(401, '{"error":"invalid_org_token"}', "u")
        assert "Ingest rejected" not in capsys.readouterr().err

    def test_does_not_count_5xx(self, capsys):
        for _ in range(6):
            get_client().handle_response(503, "", "u")
        assert "Ingest rejected" not in capsys.readouterr().err
