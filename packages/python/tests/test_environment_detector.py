import pytest
from nurse_andrea.environment_detector import detect_environment, _reset_warning


@pytest.fixture(autouse=True)
def reset_state(monkeypatch):
    for var in ("PYTHON_ENV", "ENV", "APP_ENV"):
        monkeypatch.delenv(var, raising=False)
    _reset_warning()
    yield
    _reset_warning()


def test_falls_back_to_production_when_unset():
    assert detect_environment() == "production"


@pytest.mark.parametrize("value", ["production", "staging", "development"])
def test_returns_supported_value(monkeypatch, value):
    monkeypatch.setenv("PYTHON_ENV", value)
    assert detect_environment() == value


def test_falls_back_for_unsupported_value(monkeypatch):
    monkeypatch.setenv("PYTHON_ENV", "test")
    assert detect_environment() == "production"


def test_warns_once_for_unsupported(monkeypatch, capsys):
    monkeypatch.setenv("PYTHON_ENV", "qa")
    detect_environment()
    detect_environment()
    detect_environment()
    out = capsys.readouterr().err
    assert out.count("[NurseAndrea]") == 1


def test_falls_through_to_other_env_vars(monkeypatch):
    monkeypatch.setenv("APP_ENV", "staging")
    assert detect_environment() == "staging"
