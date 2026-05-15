# nurse-andrea (Go)

NurseAndrea observability SDK for Go. Ships logs and HTTP metrics from
net/http, Gin, and Echo applications to [NurseAndrea](https://nurseandrea.io).

> Published to pkg.go.dev as `v1.2.0` alongside the Ruby gem, Node.js,
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
