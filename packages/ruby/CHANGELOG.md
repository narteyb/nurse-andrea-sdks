## [1.2.0] - 2026-05-14

### Added
- **`X-NurseAndrea-Timestamp` header on every outbound POST.** Set
  to `Time.now.to_i.to_s` (unix-seconds integer) on logs, metrics,
  and deploy. Server-side window validation (±5 minutes) lands in
  the matching NurseAndrea Rails release; requests outside the
  window are rejected with HTTP 401
  `error: "timestamp_out_of_window"`.
  This is GAP-07 Phase 2 of the replay-mitigation work — see
  `SECURITY.md` and `docs/sdk/payload-format.md` §2.1 for the
  threat-model rationale and Phase 3 (HMAC) roadmap.
- Sprint B parity test extended to assert the timestamp header is
  present and within drift on logs / metrics / deploy.

### Notes
- **Backward compatibility.** Servers running the matching Rails
  release accept requests **without** the timestamp header (older
  SDKs), so upgrading the SDK without coordinating the server
  upgrade is safe. The accept-when-absent behavior goes away in
  Phase 3.

## [1.1.0] - 2026-05-14

### Fixed (cross-runtime parity — wire spec at docs/sdk/payload-format.md)
- Status endpoint regression: `GET /nurse_andrea/status` returned
  500 since the 1.0 release because the controller's `masked_token`
  helper referenced the pre-1.0 `config.api_key` field, which raises
  `MigrationError` in 1.0. The endpoint now reads `config.org_token`.
  Caught by the new Sprint A host-app CI fixture; in-the-wild
  installs running 1.0 should upgrade to restore the health check.

### Notes
- No behavior changes in this release for Ruby host apps beyond the
  status-endpoint fix above. Ruby was already aligned with the
  cross-runtime payload spec (Sprint B audit confirmed Ruby
  emits the canonical log and metric field names —
  `occurred_at` / `source` / `payload` and `occurred_at` —
  that the spec adopts).
- Ruby-only optional emissions documented in
  docs/sdk/payload-format.md and excluded from the parity contract:
  the `User-Agent: nurse_andrea-ruby/<version>` header, per-log
  `batch_id` for request tracing, top-level `platform` on metrics
  (when platform detection is enabled), `component_discoveries`
  (when service discovery is enabled), `component_metrics` (from
  the InstrumentationSubscriber).

### Added
- `NurseAndrea::BootDiagnostics` — Sprint A D6 module that provides
  per-cause warn messages from the Railtie when configuration is
  incomplete. Replaces the generic "Configuration incomplete at
  logger wrap time" warn with messages naming the specific failure
  mode and the env var or setter to update.

## [1.0.0] - 2026-05-06

### Breaking
- Replaced `api_key` / `token` / `ingest_token` with three required
  fields: `org_token`, `workspace_slug`, `environment`. Old field
  setters and getters now raise `NurseAndrea::MigrationError` at boot
  with a link to the migration guide. There is no compatibility shim.
- New required request headers: `Authorization: Bearer <org_token>`,
  `X-NurseAndrea-Workspace: <slug>`, `X-NurseAndrea-Environment: <env>`.
  Single-token-per-workspace auth is gone.
- `environment` must be one of `production`, `staging`, `development`.
  Anything else raises a `ConfigurationError` at `validate!` time.
  `RAILS_ENV=test` auto-detects to `production` with a one-time warning.
- `workspace_slug` is validated locally (lowercase a-z, 0-9, hyphens;
  must start with a letter; 1-64 chars). Reserved-word enforcement
  remains server-authoritative.

### Added
- `NurseAndrea::SlugValidator` — local format validation.
- `NurseAndrea::EnvironmentDetector` — auto-detection from `RAILS_ENV`
  / `RACK_ENV` with a one-time stderr warning on unsupported values.
- `NurseAndrea::MigrationError` (descends from `ConfigurationError`).
- Structured rejection handling: after 5 consecutive `401`/`403`/`422`/
  `429` responses with the same error code, the SDK prints one stderr
  warning per process lifecycle with actionable guidance keyed off the
  server's `error` field (e.g. `invalid_org_token`, `workspace_rejected`,
  `auto_create_disabled`, `similar_slug_exists`).
- `X-NurseAndrea-SDK: ruby/<version>` identity header on every request.

### Migration
- See https://docs.nurseandrea.io/sdk/migration. Short version: replace
  the single `c.token` line with `c.org_token`, `c.workspace_slug`,
  `c.environment`. Pull `org_token` from the org settings page (was
  `account.token`); pick a slug for each app/service.

## [0.1.7] - 2026-04-06

### Added
- `RAILWAY_SERVICE_NAME` is now the first candidate for auto-detecting
  `service_name`. Priority: RAILWAY_SERVICE_NAME → NURSE_ANDREA_SERVICE_NAME → Rails app name.

### Fixed
- `default_service_name` uses `.presence` on all ENV candidates to treat
  empty strings as absent.

## [0.1.6] - 2026-04-06

### Fixed
- `MetricsMiddleware` now inserted using `after: :load_config_initializers`,
  matching `wrap_logger`. Consumer apps no longer need `config.before_initialize`.

## [0.1.5] - 2026-04-06

### Fixed
- Added `require 'delegate'` for Ruby 4.0 compatibility. `SimpleDelegator`
  is no longer auto-loaded in Ruby 4.0.

## [0.1.4] - 2026-04-06

### Added
- `sdk_version` and `sdk_language` included in all outbound payloads
  (log batches, metric batches). Dashboard can display SDK version and
  surface update nudges.

## [0.1.3] - 2026-04-06

### Fixed
- Railtie `wrap_logger` now runs after `config/initializers/` using
  `after: :load_config_initializers`. Standard Rails initializer placement
  now works correctly.
- MetricsMiddleware insertion deferred to after initialization.
- Silent no-op replaced with clear STDERR warning when token is missing at boot.

### Added
- `service_name` configuration attribute — auto-detected from Rails app name,
  overridable via `NURSE_ANDREA_SERVICE_NAME` env var or `c.service_name =`.
- `service_name` included in all log and metric payloads.
- `NurseAndrea::ConfigurationError` for explicit validation failures.
- Install generator adds `.nurse_andrea_backfill_done` to `.gitignore`.

## [0.1.2] - 2026-04-05

### Added
- `NurseAndrea::Configuration#host` — configurable base URL for all SDK endpoints. Defaults to `https://nurseandrea.io`.
- All ingest, metrics, traces, and handshake URLs are now derived from `host`. Nothing is hardcoded.
- `token` / `token=` aliases for `api_key` / `api_key=`

### Migration
Add `c.host = ENV.fetch("NURSE_ANDREA_HOST", "https://nurseandrea.io")` to your initializer.

## [0.1.1] - 2026-04-05

### Changed
- LogInterceptor now captures OpenTelemetry trace_id and span_id in log metadata when an OTel span is active

## [0.1.0] - 2026-04-03

### Added
- Initial release
- Log shipping via background thread (thread-safe queue, configurable batch size and flush interval)
- Request metrics via Rack middleware (duration, status, normalized path)
- Log backfill on first connection (configurable hours, JSON and plaintext log formats)
- Handshake/status endpoint at `/nurse_andrea/status`
- Rails install generator (`rails generate nurse_andrea:install`)
- Zero runtime dependencies beyond Ruby stdlib
