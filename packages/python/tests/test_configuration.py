from nurse_andrea.configuration import NurseAndreaConfig, configure

def test_defaults_to_production_host():
    c = NurseAndreaConfig(token="test")
    assert c.host == "https://nurseandrea.io"

def test_derives_ingest_url():
    c = NurseAndreaConfig(token="test", host="http://localhost:4500")
    assert c.ingest_url == "http://localhost:4500/api/v1/ingest"

def test_strips_trailing_slash():
    c = NurseAndreaConfig(token="test", host="https://staging.nurseandrea.io/")
    assert c.metrics_url == "https://staging.nurseandrea.io/api/v1/metrics"

def test_reads_env_vars(monkeypatch):
    monkeypatch.setenv("NURSE_ANDREA_TOKEN", "env-token")
    monkeypatch.setenv("NURSE_ANDREA_HOST", "https://staging.nurseandrea.io")
    c = NurseAndreaConfig()
    assert c.token == "env-token"
    assert c.host == "https://staging.nurseandrea.io"

def test_railway_service_name_priority(monkeypatch):
    monkeypatch.setenv("RAILWAY_SERVICE_NAME", "my-web")
    monkeypatch.setenv("NURSE_ANDREA_SERVICE_NAME", "other")
    c = NurseAndreaConfig(token="test")
    assert c.service_name == "my-web"

def test_disabled_when_no_token(monkeypatch):
    monkeypatch.delenv("NURSE_ANDREA_TOKEN", raising=False)
    c = NurseAndreaConfig()
    assert c.enabled is False

def test_valid_with_token_and_host():
    c = NurseAndreaConfig(token="abc", host="https://nurseandrea.io")
    assert c.is_valid() is True
