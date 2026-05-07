# NurseAndrea SDK 1.0 migration guide

## Why

The 1.0 auth contract replaces a single per-workspace token with three
fields that disambiguate **org** (who's ingesting), **workspace** (where
ingest lands), and **environment** (production / staging / development).
This unlocks:

- One token per org, used across many workspaces.
- Auto-creation of new workspaces by slug on first ingest.
- Per-environment ingest routing.

## What changed

| Before (0.x) | After (1.0) |
|---|---|
| `token` (or `api_key`, `ingest_token`) | `org_token`, `workspace_slug`, `environment` (all three required) |
| `Authorization: Bearer <token>` | `Authorization: Bearer <org_token>` + `X-NurseAndrea-Workspace: <slug>` + `X-NurseAndrea-Environment: <env>` |
| Workspaces created in the dashboard before ingesting | Slugs auto-create workspaces in `pending` state on first ingest (org-scoped policy permitting) |

## Per-language migration

### Ruby

Before:

```ruby
NurseAndrea.configure do |c|
  c.token = ENV["NURSE_ANDREA_TOKEN"]
  c.host  = ENV.fetch("NURSE_ANDREA_HOST", "https://nurseandrea.io")
end
```

After:

```ruby
NurseAndrea.configure do |c|
  c.org_token      = ENV.fetch("NURSE_ANDREA_ORG_TOKEN")
  c.workspace_slug = "checkout"
  c.environment    = ENV.fetch("RAILS_ENV", "production")
  c.host           = ENV.fetch("NURSE_ANDREA_HOST", "https://nurseandrea.io")
end
```

If you set `c.token=`, `c.api_key=`, or `c.ingest_token=` after upgrading,
the SDK raises `NurseAndrea::MigrationError` at boot.

### Node

Before:

```js
configure({ token: process.env.NURSE_ANDREA_TOKEN })
```

After:

```js
configure({
  orgToken:      process.env.NURSE_ANDREA_ORG_TOKEN,
  workspaceSlug: "checkout",
  environment:   process.env.NODE_ENV || "production",
})
```

Passing `token`, `apiKey`, or `ingestToken` throws `MigrationError`.

### Python

Before:

```python
nurse_andrea.configure(token=os.environ["NURSE_ANDREA_TOKEN"])
```

After:

```python
nurse_andrea.configure(
    org_token=os.environ["NURSE_ANDREA_ORG_TOKEN"],
    workspace_slug="checkout",
    environment=os.environ.get("PYTHON_ENV", "production"),
)
```

`token=`, `api_key=`, or `ingest_token=` raises `MigrationError`.

### Go

Before:

```go
nurseandrea.Configure(nurseandrea.Config{Token: os.Getenv("NURSE_ANDREA_TOKEN")})
```

After:

```go
err := nurseandrea.Configure(nurseandrea.Config{
    OrgToken:      os.Getenv("NURSE_ANDREA_ORG_TOKEN"),
    WorkspaceSlug: "checkout",
    Environment:   "production",
})
```

`Token`, `APIKey`, or `IngestToken` set on the struct returns
`*MigrationError` from `Configure`.

## Where to get the org_token

Org tokens live at **org settings → ingest tokens** in the NurseAndrea
dashboard. They start with `org_` and are 32+ chars. One token per org;
share across services.

## Picking a workspace_slug

A workspace represents one app/service in one environment. Pick a stable
human-readable slug per service (e.g. `checkout`, `web-frontend`,
`worker-billing`). The same slug across `environment=production` and
`environment=staging` produces two distinct workspaces (one per env).

Slug rules: lowercase letters, digits, hyphens; must start with a letter;
1-64 chars. Reserved words (`admin`, `api`, etc.) are blocked
server-side.

## Environment values

Strict enum: `production`, `staging`, `development`. Anything else raises
a `ConfigurationError`.

The SDK auto-detects from a runtime env var per language:

| Language | Source | Fallback |
|---|---|---|
| Ruby | `RAILS_ENV` → `RACK_ENV` | `production` |
| Node | `NODE_ENV` | `production` |
| Python | `PYTHON_ENV` → `ENV` → `APP_ENV` | `production` |
| Go | `GO_ENV` → `APP_ENV` | `production` |

If the auto-detected value is something else (most commonly `RAILS_ENV=test`),
the SDK prints a one-time stderr warning and uses `production`.

## New error responses

Each SDK now interprets structured ingest error codes and prints an
actionable warning after 5 consecutive rejections of the same code:

| Code | Meaning | What to do |
|---|---|---|
| `invalid_org_token` | Bad/inactive org token | Check `NURSE_ANDREA_ORG_TOKEN`. |
| `workspace_rejected` | Workspace was rejected by an org owner | Restore in dashboard or change `workspace_slug`. |
| `workspace_limit_exceeded` | Org has hit its workspace limit | Reject unused workspaces or upgrade plan. |
| `auto_create_disabled` | Org has auto-create off | Create the workspace explicitly in the dashboard. |
| `environment_not_accepted_by_this_install` | NA install rejects this `environment` value | Check `NURSE_ANDREA_HOST` (you may be hitting prod from dev). |
| `invalid_workspace_slug` | Slug doesn't match the format rules | Fix the slug per the rules above. |
| `similar_slug_exists` | A close-but-different slug already exists | Use the existing slug. |
| `creation_rate_limit_exceeded` | Too many new workspaces too fast | Slow down workspace creation; existing ingest unaffected. |

## Verification

After upgrading, watch your host's stderr for:

- `[NurseAndrea] Shipping to ... (workspace=<slug>/<env>)` — banner on
  successful boot.
- `[NurseAndrea] Ingest rejected (5+ consecutive). ...` — sustained
  rejection. The error code and guidance line tell you exactly what to fix.

If you see neither line within ~10 seconds of boot, your token isn't
propagating; double-check `NURSE_ANDREA_ORG_TOKEN`.
