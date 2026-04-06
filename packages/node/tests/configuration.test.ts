import { configure, getConfig, ingestUrl, metricsUrl, isEnabled } from "../src/configuration"

describe("Configuration", () => {
  beforeEach(() => {
    // Force re-configure
    configure({ token: "reset" })
  })

  it("defaults host to production NurseAndrea", () => {
    configure({ token: "test-token" })
    expect(getConfig().host).toBe("https://nurseandrea.io")
  })

  it("derives ingestUrl from host", () => {
    configure({ token: "test-token", host: "http://localhost:4500" })
    expect(ingestUrl()).toBe("http://localhost:4500/api/v1/ingest")
  })

  it("strips trailing slash from host", () => {
    configure({ token: "test-token", host: "https://staging.nurseandrea.io/" })
    expect(metricsUrl()).toBe("https://staging.nurseandrea.io/api/v1/metrics")
  })

  it("disables monitoring when token is missing", () => {
    configure({ token: "" })
    expect(getConfig().enabled).toBe(false)
  })

  it("reads from env vars when not explicitly configured", () => {
    process.env.NURSE_ANDREA_TOKEN = "env-token"
    process.env.NURSE_ANDREA_HOST = "https://staging.nurseandrea.io"
    configure({})
    expect(getConfig().token).toBe("env-token")
    expect(getConfig().host).toBe("https://staging.nurseandrea.io")
    delete process.env.NURSE_ANDREA_TOKEN
    delete process.env.NURSE_ANDREA_HOST
  })

  it("accepts serviceName override", () => {
    configure({ token: "test-token", serviceName: "my-app" })
    expect(getConfig().serviceName).toBe("my-app")
  })

  it("isEnabled returns false when no token", () => {
    configure({ token: "" })
    expect(isEnabled()).toBe(false)
  })
})
