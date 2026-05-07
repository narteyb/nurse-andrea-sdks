import { configure, _resetForTests } from "../src/configuration"
import { client } from "../src/client"

global.fetch = jest.fn().mockResolvedValue({ ok: true, status: 200 }) as jest.Mock

const validConfig = () => ({
  orgToken: "org_test_token",
  workspaceSlug: "checkout",
  environment: "development" as const,
  host: "http://localhost:4500",
  enabled: true,
  flushIntervalMs: 99999,
})

describe("NurseAndreaClient", () => {
  let stderrSpy: jest.SpyInstance

  beforeEach(() => {
    _resetForTests()
    configure(validConfig())
    client.resetRejectionState()
    jest.clearAllMocks()
    stderrSpy = jest.spyOn(process.stderr, "write").mockImplementation(() => true)
  })

  afterEach(() => {
    client.stop()
    stderrSpy.mockRestore()
  })

  describe("queue behavior", () => {
    it("enqueues log entries", () => {
      client.enqueueLog({ level: "info", message: "hello" })
      expect((client as any).logQueue.length).toBeGreaterThanOrEqual(1)
    })

    it("enqueues metric entries with service tag", () => {
      client.enqueueMetric({ name: "http.request.duration", value: 42, unit: "ms" })
      const metric = (client as any).metricQueue.find((m: any) => m.value === 42)
      expect(metric).toBeDefined()
      expect(metric.tags.service).toBeDefined()
    })
  })

  describe("buildHeaders", () => {
    it("emits the new auth contract", () => {
      const h = client.buildHeaders()
      expect(h["Authorization"]).toBe("Bearer org_test_token")
      expect(h["X-NurseAndrea-Workspace"]).toBe("checkout")
      expect(h["X-NurseAndrea-Environment"]).toBe("development")
      expect(h["X-NurseAndrea-SDK"]).toBe("node/1.0.0")
    })
  })

  describe("handleResponse rejection counter", () => {
    const fakeResponse = (status: number, body: object = {}) =>
      ({
        status,
        clone: () => ({ json: async () => body }),
      } as unknown as Response)

    const wasWarned = () =>
      stderrSpy.mock.calls
        .map(args => String(args[0]))
        .some(s => s.includes("Ingest rejected"))

    it("stays silent for 4 consecutive rejections", async () => {
      for (let i = 0; i < 4; i++) {
        await client.handleResponse(
          fakeResponse(401, { error: "invalid_org_token" }),
          "http://localhost:4500/api/v1/ingest"
        )
      }
      expect(wasWarned()).toBe(false)
    })

    it("warns once after 5 consecutive rejections of the same error code", async () => {
      for (let i = 0; i < 8; i++) {
        await client.handleResponse(
          fakeResponse(401, { error: "invalid_org_token" }),
          "http://localhost:4500/api/v1/ingest"
        )
      }
      const warnings = stderrSpy.mock.calls
        .map(args => String(args[0]))
        .filter(s => s.includes("Ingest rejected"))
      expect(warnings).toHaveLength(1)
      expect(warnings[0]).toContain("invalid_org_token")
      expect(warnings[0]).toContain("Check NURSE_ANDREA_ORG_TOKEN")
    })

    it("resets on a successful response", async () => {
      for (let i = 0; i < 4; i++) {
        await client.handleResponse(
          fakeResponse(401, { error: "invalid_org_token" }),
          "u"
        )
      }
      await client.handleResponse(fakeResponse(200), "u")
      for (let i = 0; i < 4; i++) {
        await client.handleResponse(
          fakeResponse(401, { error: "invalid_org_token" }),
          "u"
        )
      }
      expect(wasWarned()).toBe(false)
    })

    it("does not count 5xx as a rejection", async () => {
      for (let i = 0; i < 6; i++) {
        await client.handleResponse(fakeResponse(503), "u")
      }
      expect(wasWarned()).toBe(false)
    })
  })
})
