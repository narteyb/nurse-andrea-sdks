from nurse_andrea.configuration import configure
from nurse_andrea.client import NurseAndreaClient

def test_enqueues_log():
    configure(token="test-token", enabled=True, flush_interval_seconds=9999)
    client = NurseAndreaClient()
    client.enqueue_log("info", "hello world")
    assert len(client._log_queue) == 1
    assert client._log_queue[0].message == "hello world"

def test_enqueues_metric_with_service_tag():
    configure(token="test-token", enabled=True, flush_interval_seconds=9999)
    client = NurseAndreaClient()
    client.enqueue_metric("http.server.duration", 42.0, "ms")
    assert len(client._metric_queue) == 1
    assert "service" in client._metric_queue[0].tags

def test_does_not_enqueue_when_disabled():
    configure(token="", enabled=False)
    client = NurseAndreaClient()
    client.enqueue_log("info", "ignored")
    assert len(client._log_queue) == 0
