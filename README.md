# NurseAndrea SDKs

Multi-language SDK monorepo for [NurseAndrea](https://nurseandrea.io) observability.

## Packages

| Package | Language | Version | Registry |
|---------|----------|---------|----------|
| `packages/ruby` | Ruby | `1.0.0` | `nurse_andrea` (RubyGems) |
| `packages/node` | Node.js | `1.0.0` | `nurse-andrea` (npm) |
| `packages/python` | Python | `1.0.0` | `nurse-andrea` (PyPI) |
| `packages/go` | Go | `v1.0.0` | `github.com/narteyb/nurse-andrea-sdks/packages/go` |

## 1.0 auth contract

Every SDK uses three required fields:

- **`org_token`** — your organization's ingest token (starts with `org_`).
- **`workspace_slug`** — which workspace within the org receives ingest.
  Lowercase letters, digits, hyphens; starts with a letter; 1-64 chars.
  A new slug auto-creates as a pending workspace on first ingest.
- **`environment`** — one of `production`, `staging`, `development`.

Pulled together into three HTTP headers on every outbound request:

```
Authorization: Bearer <org_token>
X-NurseAndrea-Workspace: <slug>
X-NurseAndrea-Environment: <env>
```

## Per-language config

### Ruby

```ruby
NurseAndrea.configure do |c|
  c.org_token      = ENV.fetch("NURSE_ANDREA_ORG_TOKEN")
  c.workspace_slug = "checkout"
  c.environment    = ENV.fetch("RAILS_ENV", "production")
  c.host           = ENV.fetch("NURSE_ANDREA_HOST", "https://nurseandrea.io")
end
```

### Node

```javascript
import { configure } from "nurse-andrea"

configure({
  orgToken:      process.env.NURSE_ANDREA_ORG_TOKEN,
  workspaceSlug: "checkout",
  environment:   process.env.NODE_ENV || "production",
  host:          process.env.NURSE_ANDREA_HOST || "https://nurseandrea.io",
})
```

### Python

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

### Go

```go
import "github.com/narteyb/nurse-andrea-sdks/packages/go/nurseandrea"

func main() {
    if err := nurseandrea.Configure(nurseandrea.Config{
        OrgToken:      os.Getenv("NURSE_ANDREA_ORG_TOKEN"),
        WorkspaceSlug: "checkout",
        Environment:   nurseandrea.DetectEnvironment(),
        Host:          os.Getenv("NURSE_ANDREA_HOST"),
    }); err != nil {
        log.Fatal(err)
    }
    defer nurseandrea.Shutdown()
}
```

## Migrating from 0.x

Per-package CHANGELOGs document the breaking change. The short version, identical across languages: replace your single token field with the three new fields above. Setting `api_key` / `token` / `ingest_token` (Ruby/Python), `apiKey` / `token` / `ingestToken` (Node), or `Token` / `APIKey` / `IngestToken` (Go) raises a `MigrationError` at boot pointing here.

See [`docs/sdk/migration.md`](docs/sdk/migration.md) for the full guide.
