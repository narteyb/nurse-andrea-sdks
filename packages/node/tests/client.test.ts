import { client } from "../src/client"
import { configure } from "../src/configuration"

global.fetch = jest.fn().mockResolvedValue({ ok: true }) as jest.Mock

beforeEach(() => {
  configure({ token: "test-token", enabled: true, flushIntervalMs: 99999 })
  jest.clearAllMocks()
})

describe("NurseAndreaClient", () => {
  it("enqueues log entries", () => {
    client.enqueueLog({ level: "info", message: "hello" })
    expect((client as any)["logQueue"].length).toBeGreaterThanOrEqual(1)
  })

  it("enqueues metric entries with service tag", () => {
    client.enqueueMetric({ name: "http.request.duration", value: 42, unit: "ms" })
    const metric = (client as any)["metricQueue"].find((m: any) => m.value === 42)
    expect(metric).toBeDefined()
    expect(metric.tags.service).toBeDefined()
  })

  it("does not enqueue when disabled", () => {
    configure({ token: "", enabled: false })
    const before = (client as any)["logQueue"].length
    client.enqueueLog({ level: "info", message: "ignored" })
    expect((client as any)["logQueue"].length).toBe(before)
  })
})
