# nurse-andrea (Python)

NurseAndrea observability SDK for Python — version `1.3.0`. Ships
logs and HTTP metrics from Django, FastAPI, and Flask apps to
[NurseAndrea](https://nurseandrea.io).

## Install

```bash
pip install nurse-andrea
# Framework extras (pick one):
pip install 'nurse-andrea[django]'
pip install 'nurse-andrea[fastapi]'
pip install 'nurse-andrea[flask]'
```

## Configure

```python
import os
import nurse_andrea

nurse_andrea.configure(
    org_token=os.environ["NURSE_ANDREA_ORG_TOKEN"],
    workspace_slug="checkout",
    environment=os.environ.get("PYTHON_ENV", "production"),
    host=os.environ.get("NURSE_ANDREA_HOST", "https://nurseandrea.io"),
)
```

## Environment variables

| Variable | Required | Default |
|---|---|---|
| `NURSE_ANDREA_ORG_TOKEN` | Yes | — |
| `NURSE_ANDREA_HOST` | No | `https://nurseandrea.io` |
| `NURSE_ANDREA_SERVICE_NAME` | No | auto-detected |

## Migration from 0.x

The 1.0 auth contract replaces a single `token` / `api_key` /
`ingest_token` field with three required fields: `org_token`,
`workspace_slug`, `environment`. Setting any of the legacy fields
raises `MigrationError` at boot. See
[`docs/sdk/migration.md`](../../docs/sdk/migration.md) for the
full guide.
