import { deploy } from "../src/deploy"
import { configure, _resetForTests } from "../src/configuration"

const mockFetch = jest.fn()
global.fetch = mockFetch as unknown as typeof fetch

beforeEach(() => {
  _resetForTests()
  configure({
    orgToken: "org_test_token",
    workspaceSlug: "checkout",
    environment: "development",
    host: "http://localhost:4500",
    enabled: true,
    flushIntervalMs: 99999,
  })
  mockFetch.mockReset()
  mockFetch.mockResolvedValue({ ok: true, status: 201 })
})

describe("deploy()", () => {
  it("POSTs to /api/v1/deploy with version", async () => {
    await deploy({ version: "1.4.2" })
    expect(mockFetch).toHaveBeenCalledTimes(1)
    const [url, opts] = mockFetch.mock.calls[0]
    expect(url).toBe("http://localhost:4500/api/v1/deploy")
    const body = JSON.parse((opts as RequestInit).body as string)
    expect(body.version).toBe("1.4.2")
  })

  it("includes deployer when provided", async () => {
    await deploy({ version: "1.0.0", deployer: "dan" })
    const body = JSON.parse((mockFetch.mock.calls[0][1] as RequestInit).body as string)
    expect(body.deployer).toBe("dan")
  })

  it("defaults environment to production", async () => {
    await deploy({ version: "1.0.0" })
    const body = JSON.parse((mockFetch.mock.calls[0][1] as RequestInit).body as string)
    expect(body.environment).toBe("production")
  })

  it("honors explicit environment", async () => {
    await deploy({ version: "1.0.0", environment: "staging" })
    const body = JSON.parse((mockFetch.mock.calls[0][1] as RequestInit).body as string)
    expect(body.environment).toBe("staging")
  })

  it("stamps deployed_at as ISO 8601", async () => {
    await deploy({ version: "1.0.0" })
    const body = JSON.parse((mockFetch.mock.calls[0][1] as RequestInit).body as string)
    expect(body.deployed_at).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
  })

  it("truncates description to 500 chars", async () => {
    await deploy({ version: "1.0.0", description: "a".repeat(600) })
    const body = JSON.parse((mockFetch.mock.calls[0][1] as RequestInit).body as string)
    expect(body.description.length).toBe(500)
  })

  it("returns false and does not POST when version is empty", async () => {
    const result = await deploy({ version: "" })
    expect(result).toBe(false)
    expect(mockFetch).not.toHaveBeenCalled()
  })

  it("returns false when SDK is disabled", async () => {
    configure({
      orgToken: "org_test_token",
      workspaceSlug: "checkout",
      environment: "development",
      enabled: false,
    })
    const result = await deploy({ version: "1.0.0" })
    expect(result).toBe(false)
    expect(mockFetch).not.toHaveBeenCalled()
  })

  it("swallows network errors and returns false", async () => {
    mockFetch.mockRejectedValueOnce(new Error("ECONNREFUSED"))
    await expect(deploy({ version: "1.0.0" })).resolves.toBe(false)
  })

  it("swallows non-2xx responses and returns false", async () => {
    mockFetch.mockResolvedValueOnce({ ok: false, status: 500 })
    await expect(deploy({ version: "1.0.0" })).resolves.toBe(false)
  })
})
