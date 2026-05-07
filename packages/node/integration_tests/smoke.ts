// Smoke test for the NurseAndrea Node SDK 1.0 against a running NA instance.
//
// Usage:
//   LOCAL_ORG_TOKEN=org_xxx \
//     LOCAL_WORKSPACE_SLUG=somfo \
//     npx ts-node integration_tests/smoke.ts
//
// Optional:
//   LOCAL_NA_HOST (default: http://localhost:4500)
//
// Exits 0 on success, non-zero on failure.

import { configure } from "../src/configuration"
import { client } from "../src/client"
import { SDK_VERSION, SDK_LANGUAGE } from "../src/version"

const ORG_TOKEN = process.env.LOCAL_ORG_TOKEN
if (!ORG_TOKEN) {
  console.error("LOCAL_ORG_TOKEN is required.")
  process.exit(2)
}

const HOST = process.env.LOCAL_NA_HOST  || "http://localhost:4500"
const SLUG = process.env.LOCAL_WORKSPACE_SLUG || "smoke-test-node"

console.log(`[smoke] Configuring NurseAndrea SDK ${SDK_LANGUAGE} ${SDK_VERSION}`)
console.log(`[smoke]   host:           ${HOST}`)
console.log(`[smoke]   workspace_slug: ${SLUG}`)
console.log(`[smoke]   environment:    development`)

configure({
  orgToken:      ORG_TOKEN,
  workspaceSlug: SLUG,
  environment:   "development",
  host:          HOST,
  enabled:       true,
  batchSize:     1,
  flushIntervalMs: 60_000, // we'll flush manually via direct fetch
})

;(async () => {
  console.log("[smoke] Posting 5 ingest payloads via fetch with SDK headers...")

  let success = 0
  for (let i = 0; i < 5; i++) {
    const headers = client.buildHeaders()
    const res = await fetch(`${HOST}/api/v1/ingest`, {
      method: "POST",
      headers,
      body: JSON.stringify({
        services:     ["smoke-test-node"],
        sdk_version:  SDK_VERSION,
        sdk_language: SDK_LANGUAGE,
        logs: [
          {
            level:       "info",
            message:     `smoke test #${i}`,
            occurred_at: new Date().toISOString(),
            source:      "smoke-test-node",
            payload:     { iteration: i, node_version: process.version },
          },
        ],
      }),
    })
    if (res.status >= 200 && res.status < 300) {
      success += 1
      process.stdout.write(".")
    } else {
      process.stdout.write(`x(${res.status})`)
    }
  }
  console.log()

  if (success === 5) {
    console.log("[smoke] OK — all 5 events accepted.")
    client.stop()
    process.exit(0)
  } else {
    console.error(`[smoke] FAIL — only ${success}/5 events accepted.`)
    client.stop()
    process.exit(1)
  }
})()
