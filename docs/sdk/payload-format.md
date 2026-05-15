# NurseAndrea SDK — Payload Format

This document describes the wire-level format every NurseAndrea SDK
(Ruby, Node, Python, Go) emits when posting to the NurseAndrea
ingest endpoints. It is grounded in **observed behavior** — the
SDKs were traced before this spec was written, not specified
first. Where runtimes diverged at audit time, the audit findings
are documented inline and the canonical form is declared.

The spec is the contract that the cross-runtime parity test
(`.github/workflows/sdk-parity.yml`) enforces. A change to wire
behavior must update this document and the parity test together.

## 1. Endpoints

All endpoints are derived from `config.host` (default
`https://nurseandrea.io`). All methods are `POST`. All requests
carry the headers listed in §2.

| Path | Payload type | Triggered by |
|---|---|---|
| `/api/v1/ingest` | **Logs** | `LogShipper#flush` (Ruby) / `NurseAndreaClient._flush_sync` (Python) / `client.flush` (Node) / `Client.flush` (Go) — whenever the log batch reaches `batch_size` or the flush interval fires |
| `/api/v1/metrics` | **Metrics** (and optionally component telemetry + discoveries) | Same flushers as logs, separate POST |
| `/api/v1/deploy` | **Deploy events** | `NurseAndrea.deploy(...)` — called explicitly at app deploy time |
| `/api/v1/traces` | (Reserved) | Sprint 4.1 distributed-tracing exporter; out of scope for this spec |
| `/api/v1/handshake` | (Reserved) | Future SDK-server capability negotiation; out of scope |

This spec covers the three live payload types: **logs, metrics, deploy**.

## 2. Required headers (all payload types, all runtimes)

| Header | Value template | Source |
|---|---|---|
| `Content-Type` | `application/json` | static |
| `Authorization` | `Bearer <org_token>` | `config.org_token` |
| `X-NurseAndrea-Workspace` | `<slug>` | `config.workspace_slug` |
| `X-NurseAndrea-Environment` | `<env>` | `config.environment` ∈ {production, staging, development} |
| `X-NurseAndrea-SDK` | `<lang>/<version>` | `<sdk_language>/<sdk_version>` — e.g. `ruby/1.0.0`, `node/1.0.0`, `python/1.0.0`, `go/1.0.0` |

### 2.1 Ruby-only addition: `User-Agent`

Ruby's `HttpClient` sets `User-Agent: nurse_andrea-ruby/<version>`
in addition to the five headers above. This is a conventional Ruby
HTTP-client header that the other three runtimes do not emit.
Documented as **Ruby-only optional**. Parity tests do not assert
its absence/presence — they only assert the five common headers.

## 3. Payload type: Logs

`POST /api/v1/ingest`

### 3.1 Top-level body

```json
{
  "services":     ["<service_name>"],
  "sdk_version":  "1.0.0",
  "sdk_language": "ruby|node|python|go",
  "logs":         [ /* see §3.2 */ ]
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `services` | array of string | yes | One element today: `config.service_name`. Reserved for multi-service hosts. |
| `sdk_version` | string | yes | Matches the SDK runtime's version constant |
| `sdk_language` | string ∈ {`ruby`, `node`, `python`, `go`} | yes | Identifies the emitting runtime |
| `logs` | array of log entries | yes | May be empty if the flush was triggered by an interval with no enqueued logs (in practice the flusher short-circuits) |

### 3.2 Log entry

```json
{
  "level":       "info",
  "message":     "...",
  "occurred_at": "2026-05-14T21:54:49.000Z",
  "source":      "<service_name>",
  "payload":     { /* optional metadata */ }
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `level` | string ∈ {debug, info, warn, error, fatal} | yes | Application log level |
| `message` | string | yes | Log message body |
| `occurred_at` | ISO-8601 string (UTC) | yes | When the log was emitted in the host app |
| `source` | string | yes | Defaults to `config.service_name`; can be overridden per entry for cross-service cascade detection (Ruby `LogShipper#enqueue source:` override) |
| `payload` | object | no | Arbitrary structured metadata. Omitted or `{}` when absent. |

### 3.3 Ruby-only optional field: `batch_id`

Ruby's `LogShipper#ship` adds a `batch_id` (UUID) per log entry for
request-tracing on the server side. Other runtimes do not emit this
field. **Ruby-only optional**, not part of the parity contract.

### 3.4 Audit divergence resolved: Go log entry field names

**Pre-Sprint-B Go's `LogEntry` struct** emitted `timestamp`,
`service`, and `metadata` as JSON keys (with `sdk_version` and
`sdk_language` duplicated per entry). Ruby, Node, and Python all
emitted `occurred_at`, `source`, and `payload` with the SDK fields
only at the top level. **Sprint B Deliverable 2 aligned Go to the
3-runtime consensus.** Resolution: Go's struct field names stay
Go-idiomatic (`Timestamp`, `Service`, `Metadata`); only the JSON
tags changed (`json:"occurred_at"`, `json:"source"`,
`json:"payload"`). Per-entry SDK fields removed from JSON output.

## 4. Payload type: Metrics

`POST /api/v1/metrics`

### 4.1 Top-level body

```json
{
  "sdk_version":  "1.0.0",
  "sdk_language": "ruby|node|python|go",
  "metrics":      [ /* see §4.2 */ ]
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `sdk_version` | string | yes | |
| `sdk_language` | string | yes | |
| `metrics` | array of metric entries | yes | |

### 4.2 Metric entry

```json
{
  "name":        "process.memory.rss",
  "value":       104857600,
  "unit":        "bytes",
  "occurred_at": "2026-05-14T21:54:49.000Z",
  "tags":        { "service": "<service_name>" }
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | string | yes | Dotted-namespace metric name (e.g. `http.request.duration_ms`, `process.memory.rss`) |
| `value` | number | yes | Numeric measurement |
| `unit` | string | yes | Unit of measurement (e.g. `ms`, `bytes`, `count`) |
| `occurred_at` | ISO-8601 string (UTC) | yes | When the metric was sampled |
| `tags` | object<string, string> | yes | Always includes `service: <service_name>`; callers can add more |

### 4.3 Audit divergence resolved: metric entry timestamp field name

**Pre-Sprint-B** Ruby and Python emitted `occurred_at`; Node and
Go emitted `timestamp`. The wire-level field name diverged 2-vs-2.
**Sprint B Deliverable 2 aligned Node and Go to `occurred_at`**
(the existing Ruby+Python convention).

### 4.4 Optional top-level fields (intentional, runtime-dependent)

These appear on the metrics body when the emitting runtime supports
the corresponding feature. Their presence/absence is not part of
the parity contract — the receiving server treats them as optional.

| Field | Emitted by | When |
|---|---|---|
| `platform` | Ruby, Node | When `config.platform_detection = true` and a platform context (Railway / Render / Fly / etc.) was detected |
| `component_discoveries` | Ruby, Node | When `config.service_discovery = true` and managed services (DATABASE_URL, REDIS_URL, etc.) were discovered. Flushed once. |
| `component_metrics` | Ruby only | When the `InstrumentationSubscriber` (sql.active_record, cache_*, perform.active_job, etc.) has telemetry to flush. Ruby-specific because the subscriber is ActiveSupport::Notifications-based and has no direct equivalent in other runtimes yet. |

**Audit findings preserved as intentional divergences:** Python and
Go don't yet have platform detection or managed-service discovery
infrastructure. Adding it is a behavior change, out of scope for
Sprint B. The spec documents the optional shape so future runtimes
can adopt it without breaking the contract.

## 5. Payload type: Deploy

`POST /api/v1/deploy`

Fire-and-forget. Triggered by an explicit `NurseAndrea.deploy(...)`
call (typically in a deploy script).

### 5.1 Body

```json
{
  "version":     "1.4.2",
  "deployer":    "dan@example.com",
  "environment": "production",
  "description": "Sprint A — CI infrastructure",
  "deployed_at": "2026-05-14T21:54:49Z"
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `version` | string | yes | Caller-supplied; typically a git SHA or semver |
| `deployer` | string \| null | no | Caller-supplied; falls back to `null` |
| `environment` | string | no | Defaults to `"production"` if not supplied |
| `description` | string \| null | no | Caller-supplied; truncated to 500 chars |
| `deployed_at` | ISO-8601 string (UTC) | yes | Set by the SDK at call time, not by the caller |

### 5.2 Audit divergence resolved: deploy header `X-NurseAndrea-SDK`

**Pre-Sprint-B** the deploy endpoint received only four of the five
canonical headers from Python, Node, and Go — `X-NurseAndrea-SDK`
was missing. Ruby's deploy goes through the shared `HttpClient`
which adds it. **Sprint B Deliverable 2 aligned Python, Node, and
Go** to attach `X-NurseAndrea-SDK` on deploy posts.

## 6. Misconfiguration degradation contract

When configuration is incomplete (missing `org_token`,
`workspace_slug`, or `environment`; invalid environment value;
malformed workspace_slug; or `config.enabled = false`), every
runtime must:

1. **Not raise** at SDK boot or at any subsequent
   `enqueue_log`/`enqueue_metric`/`deploy` call site.
2. **Not attempt any HTTP request** to the configured host. No
   bytes go on the wire while config is invalid.
3. **Emit a `warn`-level message to `stderr`** describing the
   specific failure cause. Ruby's `BootDiagnostics` (Sprint A D6)
   names six causes; other runtimes emit at least one generic
   misconfig warn at SDK boot.

The parity contract for misconfig (per
`.github/workflows/sdk-parity.yml`):
- Configuring with a missing `org_token` must not raise.
- A subsequent `enqueue_log` / `enqueue_metric` / `deploy()` call
  must return without making an HTTP request.
- (Future) per-cause messages: out of scope for this spec; each
  runtime's message granularity is allowed to differ. Sprint A D6
  upgraded Ruby's messaging; equivalent upgrades to Node/Python/Go
  are deferred.

## 7. Canonical field order (reference)

JSON field ordering on the wire is **currently unpinned** — each
runtime serializes via its native JSON library, and field order
within a JSON object is not part of the wire contract (HTTP servers
parse objects unordered).

This section documents the **reference field order** for future
signing work (Sprint C+). When request signing lands and payloads
need to be canonicalized before HMAC, this order is what every
runtime sorts to.

### 7.1 Top-level (any payload type)

1. `services` (logs only)
2. `sdk_version`
3. `sdk_language`
4. Payload type root (`logs` | `metrics`)
5. Optional fields in alphabetical order (`component_discoveries`,
   `component_metrics`, `platform`)

### 7.2 Log entry

`level`, `message`, `occurred_at`, `source`, `payload`, optional
fields alphabetical (`batch_id` for Ruby).

### 7.3 Metric entry

`name`, `value`, `unit`, `occurred_at`, `tags`.

### 7.4 Deploy

`version`, `deployer`, `environment`, `description`, `deployed_at`.

## 8. Versioning

This spec is versioned together with the SDKs themselves. A wire-
breaking change requires a coordinated major-version bump across
all four runtimes (the same mechanism the 1.0 release used —
`f8fecc1` in git history). The release-automation workflow
(`.github/workflows/release.yml`) enforces version parity across
runtimes at tag time.
