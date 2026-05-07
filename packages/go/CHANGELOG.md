# Changelog

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
