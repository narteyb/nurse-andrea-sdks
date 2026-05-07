## [1.0.0] - 2026-05-06

### Breaking
- Replaced `token` / `api_key` / `ingest_token` with three required
  fields: `org_token`, `workspace_slug`, `environment`. Passing any of
  the legacy field names to `configure()` raises `MigrationError` at boot.
  There is no compatibility shim.
- New required request headers: `Authorization: Bearer <org_token>`,
  `X-NurseAndrea-Workspace: <slug>`, `X-NurseAndrea-Environment: <env>`.
- `environment` must be one of `production`, `staging`, `development`.
  Anything else raises `ConfigurationError` at validation time. Auto-detection
  reads `PYTHON_ENV`, `ENV`, then `APP_ENV`; unsupported values fall back
  to `production` with a one-time stderr warning.
- `workspace_slug` is validated locally (lowercase a-z, 0-9, hyphens; must
  start with a letter; 1-64 chars). Reserved-word enforcement remains
  server-authoritative.
- `get_config()` raises `ConfigurationError` when `configure()` hasn't run.

### Added
- `is_valid_slug` / `SLUG_RULES_HUMAN` exports.
- `detect_environment()` — env auto-detection.
- `MigrationError` (descends from `ConfigurationError`).
- Structured rejection handling: after 5 consecutive `401`/`403`/`422`/`429`
  responses with the same error code, the SDK prints one stderr warning
  per process lifecycle with actionable guidance keyed off the server's
  `error` field.
- `X-NurseAndrea-SDK: python/<version>` identity header on every request.

### Migration
- See https://docs.nurseandrea.io/sdk/migration. Short version: replace
  the `token=` argument with `org_token=`, `workspace_slug=`,
  `environment=`.

## [0.1.0] - 2026-04-06

### Added
- Initial Python SDK release
- Configuration with two-variable contract (TOKEN + HOST)
- HTTP client with batched log and metric shipping (background thread)
- Django middleware
- FastAPI/Starlette middleware
- Flask integration
- stdlib logging handler
- structlog processor
- loguru sink
- RAILWAY_SERVICE_NAME auto-detection
