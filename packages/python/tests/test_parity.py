"""Sprint B D2 — cross-runtime parity test (Python leg).

Asserts the three behavioral dimensions defined in
docs/sdk/payload-format.md: header parity, payload structure
parity, misconfiguration degradation parity. The other three
runtimes have equivalent parity tests
(ruby/spec/nurse_andrea/parity_spec.rb,
node/tests/parity.test.ts, go/nurseandrea/parity_test.go) that
assert the same shape. The .github/workflows/sdk-parity.yml
matrix runs all four; the suite is only meaningful if every leg
passes.
"""
from __future__ import annotations
import re

import httpx
import pytest
import respx

import nurse_andrea
from nurse_andrea.client import get_client
from nurse_andrea.configuration import SDK_LANGUAGE, SDK_VERSION
from nurse_andrea.deploy import deploy

VALID = dict(
    org_token="org_parity_test_aaaaaaaaaaaaaaaaaaaa",
    workspace_slug="parity-test",
    environment="development",
    host="http://parity.test",
    enabled=True,
)


@pytest.fixture(autouse=True)
def _reset():
    # Reset config + client state between tests.
    yield
    nurse_andrea.configuration._reset_for_tests()


# ─── Header parity ─────────────────────────────────────────────

@respx.mock
def test_ingest_headers_canonical():
    nurse_andrea.configure(**VALID)
    route = respx.post("http://parity.test/api/v1/ingest").mock(return_value=httpx.Response(200, json={}))

    client = get_client()
    client.enqueue_log(level="info", message="x")
    client._flush_sync()

    assert route.called
    headers = route.calls.last.request.headers
    assert headers["content-type"] == "application/json"
    assert headers["authorization"] == "Bearer org_parity_test_aaaaaaaaaaaaaaaaaaaa"
    assert headers["x-nurseandrea-workspace"] == "parity-test"
    assert headers["x-nurseandrea-environment"] == "development"
    assert re.match(r"^python/\d+\.\d+\.\d+$", headers["x-nurseandrea-sdk"])


@respx.mock
def test_metrics_headers_canonical():
    nurse_andrea.configure(**VALID)
    route = respx.post("http://parity.test/api/v1/metrics").mock(return_value=httpx.Response(200, json={}))

    client = get_client()
    client.enqueue_metric(name="process.memory.rss", value=1.0, unit="bytes")
    client._flush_sync()

    assert route.called
    headers = route.calls.last.request.headers
    assert headers["authorization"] == "Bearer org_parity_test_aaaaaaaaaaaaaaaaaaaa"
    assert headers["x-nurseandrea-workspace"] == "parity-test"
    assert headers["x-nurseandrea-environment"] == "development"
    assert re.match(r"^python/\d+\.\d+\.\d+$", headers["x-nurseandrea-sdk"])


@respx.mock
def test_deploy_headers_canonical():
    nurse_andrea.configure(**VALID)
    route = respx.post("http://parity.test/api/v1/deploy").mock(return_value=httpx.Response(200, json={}))

    deploy(version="1.0.0")

    assert route.called
    headers = route.calls.last.request.headers
    assert headers["authorization"] == "Bearer org_parity_test_aaaaaaaaaaaaaaaaaaaa"
    assert headers["x-nurseandrea-workspace"] == "parity-test"
    assert headers["x-nurseandrea-environment"] == "development"
    # Sprint B D2 added X-NurseAndrea-SDK to Python's deploy headers.
    assert re.match(r"^python/\d+\.\d+\.\d+$", headers["x-nurseandrea-sdk"])


# ─── Payload structure parity ─────────────────────────────────

@respx.mock
def test_log_payload_canonical_fields():
    nurse_andrea.configure(**VALID)
    route = respx.post("http://parity.test/api/v1/ingest").mock(return_value=httpx.Response(200, json={}))

    client = get_client()
    client.enqueue_log(level="info", message="parity", metadata={"k": "v"})
    client._flush_sync()

    body = route.calls.last.request.content
    import json
    parsed = json.loads(body)
    assert set(parsed.keys()) >= {"services", "sdk_version", "sdk_language", "logs"}
    assert parsed["sdk_language"] == "python"
    entry = parsed["logs"][0]
    assert set(entry.keys()) >= {"level", "message", "occurred_at", "source", "payload"}


@respx.mock
def test_metric_payload_canonical_fields():
    nurse_andrea.configure(**VALID)
    route = respx.post("http://parity.test/api/v1/metrics").mock(return_value=httpx.Response(200, json={}))

    client = get_client()
    client.enqueue_metric(name="process.memory.rss", value=1.0, unit="bytes")
    client._flush_sync()

    body = route.calls.last.request.content
    import json
    parsed = json.loads(body)
    assert set(parsed.keys()) >= {"sdk_version", "sdk_language", "metrics"}
    assert parsed["sdk_language"] == "python"
    entry = parsed["metrics"][0]
    assert set(entry.keys()) >= {"name", "value", "unit", "occurred_at", "tags"}


# ─── Misconfig degradation parity ─────────────────────────────

def test_missing_org_token_does_not_raise():
    nurse_andrea.configuration._reset_for_tests()
    # Should not raise.
    nurse_andrea.configure(
        org_token="",
        workspace_slug="parity-test",
        environment="development",
        host="http://parity.test",
    )
    assert nurse_andrea.is_enabled() is False

    client = get_client()
    # enqueue methods short-circuit on is_enabled() = False; no
    # HTTP attempt is made.
    client.enqueue_log(level="info", message="x")
    client.enqueue_metric(name="m", value=1.0, unit="count")
