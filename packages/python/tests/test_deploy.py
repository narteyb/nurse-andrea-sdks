import json
from unittest.mock import patch, MagicMock

from nurse_andrea.configuration import configure, _reset_for_tests
from nurse_andrea.deploy import deploy


def _mock_response(status_code=201):
    r = MagicMock()
    r.status_code = status_code
    return r


def _captured(post_mock):
    """Pull out (url, json_body) from the last httpx.Client().post call."""
    args, kwargs = post_mock.call_args
    return args[0], kwargs.get("json", {})


def setup_function(_):
    _reset_for_tests()
    configure(
        org_token="org_test_token",
        workspace_slug="checkout",
        environment="development",
        host="http://localhost:4500",
        enabled=True,
        flush_interval_seconds=9999,
    )


def test_posts_to_deploy_endpoint_with_version():
    with patch("nurse_andrea.deploy.httpx.Client") as ClientCls:
        ClientCls.return_value.__enter__.return_value.post.return_value = _mock_response()
        result = deploy(version="1.4.2")
        assert result is True
        post = ClientCls.return_value.__enter__.return_value.post
        url, body = _captured(post)
        assert url == "http://localhost:4500/api/v1/deploy"
        assert body["version"] == "1.4.2"


def test_includes_deployer_when_provided():
    with patch("nurse_andrea.deploy.httpx.Client") as ClientCls:
        ClientCls.return_value.__enter__.return_value.post.return_value = _mock_response()
        deploy(version="1.0.0", deployer="dan")
        _, body = _captured(ClientCls.return_value.__enter__.return_value.post)
        assert body["deployer"] == "dan"


def test_defaults_environment_to_production():
    with patch("nurse_andrea.deploy.httpx.Client") as ClientCls:
        ClientCls.return_value.__enter__.return_value.post.return_value = _mock_response()
        deploy(version="1.0.0")
        _, body = _captured(ClientCls.return_value.__enter__.return_value.post)
        assert body["environment"] == "production"


def test_honors_explicit_environment():
    with patch("nurse_andrea.deploy.httpx.Client") as ClientCls:
        ClientCls.return_value.__enter__.return_value.post.return_value = _mock_response()
        deploy(version="1.0.0", environment="staging")
        _, body = _captured(ClientCls.return_value.__enter__.return_value.post)
        assert body["environment"] == "staging"


def test_stamps_deployed_at_iso8601_utc():
    with patch("nurse_andrea.deploy.httpx.Client") as ClientCls:
        ClientCls.return_value.__enter__.return_value.post.return_value = _mock_response()
        deploy(version="1.0.0")
        _, body = _captured(ClientCls.return_value.__enter__.return_value.post)
        assert body["deployed_at"].endswith("Z")


def test_truncates_description_to_500_chars():
    with patch("nurse_andrea.deploy.httpx.Client") as ClientCls:
        ClientCls.return_value.__enter__.return_value.post.return_value = _mock_response()
        deploy(version="1.0.0", description="a" * 600)
        _, body = _captured(ClientCls.return_value.__enter__.return_value.post)
        assert len(body["description"]) == 500


def test_returns_false_when_version_blank():
    with patch("nurse_andrea.deploy.httpx.Client") as ClientCls:
        result = deploy(version="")
        assert result is False
        ClientCls.assert_not_called()


def test_returns_false_when_disabled():
    _reset_for_tests()
    configure(
        org_token="org_test_token",
        workspace_slug="checkout",
        environment="development",
        enabled=False,
    )
    with patch("nurse_andrea.deploy.httpx.Client") as ClientCls:
        result = deploy(version="1.0.0")
        assert result is False
        ClientCls.assert_not_called()


def test_swallows_network_errors():
    with patch("nurse_andrea.deploy.httpx.Client") as ClientCls:
        ClientCls.return_value.__enter__.return_value.post.side_effect = Exception("boom")
        assert deploy(version="1.0.0") is False


def test_swallows_non_2xx_responses():
    with patch("nurse_andrea.deploy.httpx.Client") as ClientCls:
        ClientCls.return_value.__enter__.return_value.post.return_value = _mock_response(500)
        assert deploy(version="1.0.0") is False
