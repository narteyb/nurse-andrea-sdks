import pytest
from nurse_andrea.configuration import (
    NurseAndreaConfig, configure, get_config, _reset_for_tests,
)
from nurse_andrea.errors import ConfigurationError, MigrationError


def _valid_kwargs():
    return dict(
        org_token="org_test_token",
        workspace_slug="checkout",
        environment="development",
    )


@pytest.fixture(autouse=True)
def reset():
    _reset_for_tests()
    yield
    _reset_for_tests()


def test_defaults_to_production_host():
    c = NurseAndreaConfig(**_valid_kwargs())
    assert c.host == "https://nurseandrea.io"


def test_derives_ingest_url():
    c = NurseAndreaConfig(**_valid_kwargs(), host="http://localhost:4500")
    assert c.ingest_url == "http://localhost:4500/api/v1/ingest"


def test_strips_trailing_slash():
    c = NurseAndreaConfig(**_valid_kwargs(), host="https://staging.nurseandrea.io/")
    assert c.metrics_url == "https://staging.nurseandrea.io/api/v1/metrics"


def test_reads_org_token_from_env(monkeypatch):
    monkeypatch.setenv("NURSE_ANDREA_ORG_TOKEN", "env-token")
    c = NurseAndreaConfig(workspace_slug="checkout", environment="development")
    assert c.org_token == "env-token"


def test_railway_service_name_priority(monkeypatch):
    monkeypatch.setenv("RAILWAY_SERVICE_NAME", "my-web")
    monkeypatch.setenv("NURSE_ANDREA_SERVICE_NAME", "other")
    c = NurseAndreaConfig(**_valid_kwargs())
    assert c.service_name == "my-web"


def test_is_valid_when_fully_populated():
    c = NurseAndreaConfig(**_valid_kwargs())
    assert c.is_valid() is True


def test_is_invalid_with_bad_environment():
    c = NurseAndreaConfig(org_token="x", workspace_slug="checkout", environment="qa")
    assert c.is_valid() is False


def test_is_invalid_with_bad_slug():
    c = NurseAndreaConfig(org_token="x", workspace_slug="Bad_Slug", environment="development")
    assert c.is_valid() is False


def test_validate_raises_when_org_token_missing():
    with pytest.raises(ConfigurationError, match="org_token is required"):
        NurseAndreaConfig(workspace_slug="checkout", environment="development").validate()


def test_validate_raises_when_workspace_slug_missing():
    with pytest.raises(ConfigurationError, match="workspace_slug is required"):
        NurseAndreaConfig(org_token="x", environment="development").validate()


def test_validate_raises_when_environment_unsupported():
    with pytest.raises(ConfigurationError, match="environment must be one of"):
        NurseAndreaConfig(org_token="x", workspace_slug="ok", environment="qa").validate()


def test_validate_raises_when_slug_invalid():
    with pytest.raises(ConfigurationError, match="workspace_slug.*invalid.*lowercase"):
        NurseAndreaConfig(org_token="x", workspace_slug="Bad_Slug", environment="development").validate()


@pytest.mark.parametrize("legacy", ["token", "api_key", "ingest_token"])
def test_configure_raises_migration_error_on_legacy_field(legacy):
    with pytest.raises(MigrationError, match="no longer supported"):
        configure(**{legacy: "x"})


def test_migration_error_descends_from_configuration_error():
    assert issubclass(MigrationError, ConfigurationError)
