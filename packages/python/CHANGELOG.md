## [1.3.0] - 2026-05-14

### Notes
- **No functional changes in the Python SDK this release.** Version
  bumped from 1.2.0 → 1.3.0 to stay aligned with the coordinated
  cross-runtime release tag scheme — the Ruby gem shipped the
  Rack-compatible core refactor (Sprint D D1, GAP-09) in this
  release and the four runtimes ship under a single `v<X.Y.Z>` tag
  enforced by `.github/workflows/release.yml`'s `verify_versions`
  job.

## [1.2.0] - 2026-05-14

### Added
- **`X-NurseAndrea-Timestamp` header on every outbound POST.** Set
  to `str(int(time.time()))` (unix-seconds integer) on logs,
  metrics, and deploy. Server-side window validation (±5 minutes)
  lands in the matching NurseAndrea Rails release; requests outside
  the window are rejected with HTTP 401
  `error: "timestamp_out_of_window"`.
  This is GAP-07 Phase 2 of the replay-mitigation work — see
  `SECURITY.md` and `docs/sdk/payload-format.md` §2.1 for the
  threat-model rationale and Phase 3 (HMAC) roadmap.
- Parity test extended to assert the timestamp header is present
  and within drift on logs / metrics / deploy.

### Notes
- **Backward compatibility.** Servers running the matching Rails
  release accept requests **without** the timestamp header (older
  SDKs), so upgrading the SDK without coordinating the server
  upgrade is safe. The accept-when-absent behavior goes away in
  Phase 3.

## [1.1.0] - 2026-05-14

### Breaking
- **`configure()` no longer raises `ConfigurationError` on missing /
  invalid fields.** Pre-1.1 a missing `org_token`, `workspace_slug`,
  or `environment` (or an unsupported environment value, or a
  malformed workspace_slug) raised synchronously from `configure()`.
  As of 1.1 the SDK silent-degrades to align with the cross-runtime
  misconfiguration contract documented in
  [`docs/sdk/payload-format.md`](../../docs/sdk/payload-format.md) §6:
  the validation failure is written to `stderr` as
  `[NurseAndrea] <reason> — monitoring disabled.`, `_config` is
  stored in a state where `is_enabled()` returns `False`. No HTTP
  request reaches the wire while config is invalid.

  **What this means for host apps:**
  - Apps that relied on `configure()` raising as a startup signal
    will now boot silently without monitoring. The only signal is
    the `stderr` warn line.
  - Verify SDK activation after deploy by checking
    `nurse_andrea.is_enabled()` programmatically.
  - `MigrationError` (legacy `api_key` / `token` / `ingest_token`
    field names) still raises — that's a user-error guard, not a
    config-state signal. Behavior unchanged.
  - `NurseAndreaConfig.validate()` (the standalone method, not
    called by `configure()` anymore) still raises
    `ConfigurationError` — useful for callers who want fail-fast
    semantics explicitly.

### Fixed (cross-runtime parity — wire spec at docs/sdk/payload-format.md)
- Deploy requests now attach the `X-NurseAndrea-SDK: python/<version>`
  header (Ruby was already attaching it via the shared HttpClient;
  Python was missing it on the deploy path).

### Added
- Cross-runtime parity fixture test at `tests/test_parity.py`
  exercising header / payload-structure / misconfig dimensions.

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
