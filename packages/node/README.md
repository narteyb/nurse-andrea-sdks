# nurse-andrea (Node.js)

NurseAndrea observability SDK for Node.js. Ships logs and HTTP metrics to
[NurseAndrea](https://nurseandrea.io) from Express, Fastify, and NestJS apps.

> **Note:** Pre-release (`0.1.0`). Will be published to npm as `v1.0.0`
> alongside Python and Go SDKs.

## Setup

```javascript
const { configure } = require("nurse-andrea")

configure({
  token:       process.env.NURSE_ANDREA_TOKEN,
  host:        process.env.NURSE_ANDREA_HOST || "https://nurseandrea.io",
  serviceName: "my-app",
})
```

## Express

```javascript
const { nurseAndreaExpress } = require("nurse-andrea")
app.use(nurseAndreaExpress())
```

## Fastify

```javascript
const { nurseAndreaFastify } = require("nurse-andrea")
await fastify.register(nurseAndreaFastify)
```

## Environment variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `NURSE_ANDREA_TOKEN` | Yes | — | Ingest token |
| `NURSE_ANDREA_HOST` | No | `https://nurseandrea.io` | Endpoint |
| `NURSE_ANDREA_SERVICE_NAME` | No | package.json name | Service label |
