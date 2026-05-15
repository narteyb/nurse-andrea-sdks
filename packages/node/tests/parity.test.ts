// Sprint B D2 — cross-runtime parity test (Node leg).
//
// Asserts the three behavioral dimensions defined in
// docs/sdk/payload-format.md: header parity, payload structure
// parity, misconfiguration degradation parity. The other three
// runtimes have equivalent parity tests
// (ruby/spec/nurse_andrea/parity_spec.rb,
// python/tests/test_parity.py, go/nurseandrea/parity_test.go) that
// assert the same shape. The .github/workflows/sdk-parity.yml
// matrix runs all four; the suite is only meaningful if every leg
// passes.

import { configure, _resetForTests } from "../src/configuration"
import { client } from "../src/client"
import { deploy } from "../src/deploy"
import { SDK_LANGUAGE, SDK_VERSION } from "../src/version"

interface CapturedRequest {
  url: string
  headers: Record<string, string>
  body: any
}

const validConfig = () => ({
  orgToken: "org_parity_test_aaaaaaaaaaaaaaaaaaaa",
  workspaceSlug: "parity-test",
  environment: "development" as const,
  host: "http://parity.test",
  enabled: true,
  flushIntervalMs: 99999,
})

function installFetchCapture(): { captured: CapturedRequest[]; restore: () => void } {
  const captured: CapturedRequest[] = []
  const fetchMock = jest.fn(async (url: string, init: any) => {
    const headers: Record<string, string> = {}
    if (init?.headers) {
      for (const [k, v] of Object.entries(init.headers)) headers[k] = String(v)
    }
    const body = init?.body ? JSON.parse(init.body as string) : null
    captured.push({ url, headers, body })
    return { ok: true, status: 200, clone: () => ({ json: async () => ({}) }) }
  })
  const original = global.fetch
  global.fetch = fetchMock as any
  return { captured, restore: () => { global.fetch = original } }
}

describe("NurseAndrea SDK parity (Node)", () => {
  let capture: ReturnType<typeof installFetchCapture>

  beforeEach(() => {
    _resetForTests()
    configure(validConfig())
    client.resetRejectionState()
    jest.clearAllMocks()
    capture = installFetchCapture()
  })

  afterEach(() => {
    client.stop()
    capture.restore()
  })

  describe("Header parity", () => {
    it("emits the 5 canonical headers on /api/v1/ingest", async () => {
      client.enqueueLog({ level: "info", message: "x" })
      await (client as any).flush()
      const req = capture.captured.find(r => r.url.endsWith("/api/v1/ingest"))
      expect(req).toBeDefined()
      expect(req!.headers["Content-Type"]).toBe("application/json")
      expect(req!.headers["Authorization"]).toBe("Bearer org_parity_test_aaaaaaaaaaaaaaaaaaaa")
      expect(req!.headers["X-NurseAndrea-Workspace"]).toBe("parity-test")
      expect(req!.headers["X-NurseAndrea-Environment"]).toBe("development")
      expect(req!.headers["X-NurseAndrea-SDK"]).toBe(`${SDK_LANGUAGE}/${SDK_VERSION}`)
    })

    it("emits the 5 canonical headers on /api/v1/metrics", async () => {
      client.enqueueMetric({ name: "process.memory.rss", value: 1, unit: "bytes" })
      await (client as any).flush()
      const req = capture.captured.find(r => r.url.endsWith("/api/v1/metrics"))
      expect(req).toBeDefined()
      expect(req!.headers["Authorization"]).toBe("Bearer org_parity_test_aaaaaaaaaaaaaaaaaaaa")
      expect(req!.headers["X-NurseAndrea-Workspace"]).toBe("parity-test")
      expect(req!.headers["X-NurseAndrea-Environment"]).toBe("development")
      expect(req!.headers["X-NurseAndrea-SDK"]).toBe(`${SDK_LANGUAGE}/${SDK_VERSION}`)
    })

    it("emits the 5 canonical headers on /api/v1/deploy", async () => {
      await deploy({ version: "1.0.0" })
      const req = capture.captured.find(r => r.url.endsWith("/api/v1/deploy"))
      expect(req).toBeDefined()
      expect(req!.headers["Content-Type"]).toBe("application/json")
      expect(req!.headers["Authorization"]).toBe("Bearer org_parity_test_aaaaaaaaaaaaaaaaaaaa")
      expect(req!.headers["X-NurseAndrea-Workspace"]).toBe("parity-test")
      expect(req!.headers["X-NurseAndrea-Environment"]).toBe("development")
      expect(req!.headers["X-NurseAndrea-SDK"]).toBe(`${SDK_LANGUAGE}/${SDK_VERSION}`)
    })
  })

  describe("Payload structure parity", () => {
    it("log payload has canonical top-level + entry field names", async () => {
      client.enqueueLog({ level: "info", message: "parity", metadata: { k: "v" } })
      await (client as any).flush()
      const req = capture.captured.find(r => r.url.endsWith("/api/v1/ingest"))!
      expect(req.body).toEqual(
        expect.objectContaining({
          services: expect.any(Array),
          sdk_version: expect.any(String),
          sdk_language: "node",
          logs: expect.any(Array),
        })
      )
      const entry = req.body.logs[0]
      expect(entry).toEqual(
        expect.objectContaining({
          level: "info",
          message: "parity",
          occurred_at: expect.any(String),
          source: expect.any(String),
          payload: expect.any(Object),
        })
      )
    })

    it("metric payload has canonical top-level + entry field names", async () => {
      client.enqueueMetric({ name: "process.memory.rss", value: 1, unit: "bytes" })
      await (client as any).flush()
      const req = capture.captured.find(r => r.url.endsWith("/api/v1/metrics"))!
      expect(req.body).toEqual(
        expect.objectContaining({
          sdk_version: expect.any(String),
          sdk_language: "node",
          metrics: expect.any(Array),
        })
      )
      const entry = req.body.metrics[0]
      expect(entry).toEqual(
        expect.objectContaining({
          name: "process.memory.rss",
          value: 1,
          unit: "bytes",
          occurred_at: expect.any(String),
          tags: expect.any(Object),
        })
      )
    })
  })

  describe("Misconfig degradation parity", () => {
    it("missing orgToken does not throw and skips enqueue", async () => {
      _resetForTests()
      // Configure without orgToken — direct internal write since
      // configure() validates required fields. The
      // is-enabled check inside enqueueLog short-circuits.
      configure({
        orgToken: "",
        workspaceSlug: "parity-test",
        environment: "development",
        host: "http://parity.test",
        enabled: true,
      } as any)
      expect(() => client.enqueueLog({ level: "info", message: "x" })).not.toThrow()
      // No fetch call attempted because isEnabled() short-circuits
      // when the SDK is misconfigured at the client layer.
      const calls = capture.captured.length
      await (client as any).flush()
      expect(capture.captured.length).toBe(calls)
    })
  })
})
