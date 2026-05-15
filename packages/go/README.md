# nurse-andrea (Go)

NurseAndrea observability SDK for Go. Ships logs and HTTP metrics from
net/http, Gin, and Echo applications to [NurseAndrea](https://nurseandrea.io).

> Published to pkg.go.dev as `v1.3.0` alongside the Ruby gem, Node.js,
> and Python SDKs in a coordinated release. (Setup snippet below is
> illustrative; the canonical 1.x setup using `OrgToken` +
> `WorkspaceSlug` + `Environment` is in the monorepo root README and
> [`docs/sdk/payload-format.md`](../../docs/sdk/payload-format.md).)

## Installation

```bash
go get github.com/narteyb/nurse-andrea-sdks/packages/go
```

## Setup

```go
import "github.com/narteyb/nurse-andrea-sdks/packages/go/nurseandrea"

func main() {
    nurseandrea.Configure(nurseandrea.Config{
        Token:       os.Getenv("NURSE_ANDREA_TOKEN"),
        Host:        os.Getenv("NURSE_ANDREA_HOST"),
        ServiceName: os.Getenv("NURSE_ANDREA_SERVICE_NAME"),
    })
    defer nurseandrea.Shutdown()
    // ...
}
```

## net/http

```go
import namw "github.com/narteyb/nurse-andrea-sdks/packages/go/nurseandrea/middleware"

mux := http.NewServeMux()
mux.HandleFunc("/", handler)
http.ListenAndServe(":8080", namw.NetHTTP(mux))
```

## Gin

```go
r := gin.Default()
r.Use(namw.Gin())
```

## Echo

```go
e := echo.New()
e.Use(namw.Echo())
```

## Log interception

```go
// slog (stdlib)
import "github.com/narteyb/nurse-andrea-sdks/packages/go/nurseandrea/interceptors"

base := slog.NewJSONHandler(os.Stdout, nil)
logger := slog.New(interceptors.NewSlogHandler(base))
slog.SetDefault(logger)

// zap
baseLogger, _ := zap.NewProduction()
core := interceptors.NewZapCore(baseLogger.Core())
logger := zap.New(core)
```

## Environment variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `NURSE_ANDREA_TOKEN` | Yes | — | Account ingest token |
| `NURSE_ANDREA_HOST` | No | `https://nurseandrea.io` | NurseAndrea endpoint |
| `NURSE_ANDREA_SERVICE_NAME` | No | `go-app` | Service label |
| `RAILWAY_SERVICE_NAME` | No | — | Auto-used on Railway |

## Module path and versioning

### Current path

The Go module is published as:

```
github.com/narteyb/nurse-andrea-sdks/packages/go/nurseandrea
```

This nested path reflects the monorepo layout — all four SDKs
(Ruby, Node, Python, Go) live under `packages/`. The path is
permanently established at every released v1.x tag; consumers
import it as:

```go
import "github.com/narteyb/nurse-andrea-sdks/packages/go/nurseandrea"
```

Single-package Go SDKs typically use shorter import paths (for
example `github.com/stripe/stripe-go`), but those projects are not
monorepos. The trade-off here is one extra path segment for the
import line in exchange for keeping the four runtimes versioned,
tagged, and CI'd together. No action is required at v1.x — the
import is what it is.

### v2 migration path

When a breaking change warrants a major version bump, Go module
conventions require an explicit choice. Both options are listed
here so the decision is informed when the time comes.

**Option A — Append `/v2` to the existing path.**

```
github.com/narteyb/nurse-andrea-sdks/packages/go/nurseandrea/v2
```

This is the Go-canonical approach. The directory `packages/go/nurseandrea/v2`
is created, the `go.mod` inside it declares the new major version,
and consumers update their imports to include `/v2`. The path stays
nested. No tooling outside this repo needs to change.

**Option B — Move the module to a shorter canonical path.**

```
github.com/narteyb/nurse-andrea-go
```

A new top-level repository (or a top-level module file in this
repo) hosts the v2 module under a flat name that matches the
single-package Go convention. Imports become
`github.com/narteyb/nurse-andrea-go`. This requires a brief
migration guide for existing v1.x consumers but cuts the import
line and signals "the Go SDK is a first-class artifact."

**Recommendation for the v2 decision** (when it arrives, not now):
prefer Option B. The one-time migration cost is paid once and
benefits every future consumer; Option A locks the verbose path in
forever. Track for the next major version, not Sprint D.

### Current recommendation

No action needed at v1.x. This section exists so future maintainers
have the trade-off written down when the v2 decision lands.
