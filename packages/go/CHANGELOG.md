# Changelog

## 1.1.0 (2026-05-14)

### Breaking (wire-level — host code unchanged)
- **`LogEntry` JSON wire format aligned to cross-runtime spec.**
  The `LogEntry` struct's JSON tags now serialize as
  `occurred_at` / `source` / `payload` instead of the pre-1.1
  `timestamp` / `service` / `metadata`. Per-entry `sdk_version` and
  `sdk_language` removed from the entry; they continue to ride on
  the top-level batch payload. See `docs/sdk/payload-format.md` §3.4
  for the audit finding and resolution.
- **`MetricEntry` JSON wire format aligned to cross-runtime spec.**
  Timestamp serializes as `occurred_at` (was `timestamp`).
  Per-entry SDK fields removed.

  Host code that calls `EnqueueLog` / `EnqueueMetric` is unchanged.
  The struct field names are unchanged (Go-idiomatic
  `Timestamp` / `Service` / `Metadata`); only the JSON tags moved.
  Code that JSON-marshals an SDK struct directly and compared
  output strings would need to update the expected keys.

### Fixed (cross-runtime parity — wire spec at docs/sdk/payload-format.md)
- Deploy requests now attach `X-NurseAndrea-SDK: go/<version>`
  header. Other runtimes were attaching it on logs/metrics but
  Go's deploy path was missing it.

### Added
- Cross-runtime parity test at `packages/go/parity_test.go`
  exercising header / payload-structure / misconfig dimensions.
  Misconfig behavior unchanged: `Configure` returns `error` for
  missing required fields — the Go-idiomatic non-raising form.

## 1.0.0 (2026-05-06)

### Breaking
- Replaced `Token` / `APIKey` / `IngestToken` with three required fields:
  `OrgToken`, `WorkspaceSlug`, `Environment`. Setting any of the legacy
  fields on the `Config` struct returns a `*MigrationError` from
  `Configure(...)`. There is no compatibility shim.
- New required request headers: `Authorization: Bearer <OrgToken>`,
  `X-NurseAndrea-Workspace: <slug>`, `X-NurseAndrea-Environment: <env>`.
- `Configure(Config) error` now returns an error rather than silently
  disabling on missing token. Validation rejects unsupported environment
  values (only `production`/`staging`/`development`) and invalid slugs
  (lowercase a-z, 0-9, hyphens; must start with a letter; 1-64 chars).
- `GetConfig()` panics if `Configure` has not been called — there are no
  sensible defaults for `OrgToken` / `WorkspaceSlug`.

### Added
- `IsValidSlug` / `SlugRulesHuman` exports.
- `DetectEnvironment()` — auto-detection from `GO_ENV` / `APP_ENV` with
  one-time stderr warning on unsupported values.
- `MigrationError`, `ConfigurationError`, `ErrConfiguration` (sentinel for
  `errors.Is`).
- Structured rejection handling: after 5 consecutive `401`/`403`/`422`/
  `429` responses with the same error code, the SDK prints one stderr
  warning per process lifecycle with actionable guidance keyed off the
  server's `error` field.
- `X-NurseAndrea-SDK: go/<version>` identity header on every request.

### Migration
- See https://docs.nurseandrea.io/sdk/migration. Short version: replace
  the `Token:` field with `OrgToken:`, `WorkspaceSlug:`, `Environment:`.

## 0.1.0 (2026-04-06)

- Initial release
- Configuration via `NURSE_ANDREA_TOKEN` + `NURSE_ANDREA_HOST`
- HTTP middleware: net/http, Gin, Echo
- Log interceptors: slog (stdlib), zap
- Batched async log and metric shipping
- `RAILWAY_SERVICE_NAME` auto-detection
