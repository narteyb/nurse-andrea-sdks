# nurse-andrea (Python)

NurseAndrea observability SDK for Python. Ships logs and HTTP metrics from
Django, FastAPI, and Flask apps to [NurseAndrea](https://nurseandrea.io).

> Pre-release (`0.1.0`). Will be published to PyPI as `v1.0.0`.

## Setup

```python
import nurse_andrea
nurse_andrea.configure(
    token=os.environ["NURSE_ANDREA_TOKEN"],
    host=os.environ.get("NURSE_ANDREA_HOST", "https://nurseandrea.io"),
    service_name="my-app",
)
```

## Environment variables

| Variable | Required | Default |
|---|---|---|
| `NURSE_ANDREA_TOKEN` | Yes | — |
| `NURSE_ANDREA_HOST` | No | `https://nurseandrea.io` |
| `NURSE_ANDREA_SERVICE_NAME` | No | auto-detected |
