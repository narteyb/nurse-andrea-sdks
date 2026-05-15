import {
  configure,
  getConfig,
  ingestUrl,
  metricsUrl,
  isEnabled,
  _resetForTests,
} from "../src/configuration"
import { ConfigurationError, MigrationError } from "../src/errors"

const validConfig = () => ({
  orgToken: "org_test_token",
  workspaceSlug: "checkout",
  environment: "development" as const,
})

describe("Configuration", () => {
  beforeEach(() => {
    _resetForTests()
  })

  describe("happy path", () => {
    it("defaults host to production NurseAndrea", () => {
      configure(validConfig())
      expect(getConfig().host).toBe("https://nurseandrea.io")
    })

    it("derives ingestUrl from host", () => {
      configure({ ...validConfig(), host: "http://localhost:4500" })
      expect(ingestUrl()).toBe("http://localhost:4500/api/v1/ingest")
    })

    it("strips trailing slash from host", () => {
      configure({ ...validConfig(), host: "https://staging.nurseandrea.io/" })
      expect(metricsUrl()).toBe("https://staging.nurseandrea.io/api/v1/metrics")
    })

    it("accepts serviceName override", () => {
      configure({ ...validConfig(), serviceName: "my-app" })
      expect(getConfig().serviceName).toBe("my-app")
    })

    it("reads orgToken from NURSE_ANDREA_ORG_TOKEN env var when not in options", () => {
      process.env.NURSE_ANDREA_ORG_TOKEN = "env-token"
      configure({ workspaceSlug: "checkout", environment: "development" })
      expect(getConfig().orgToken).toBe("env-token")
      delete process.env.NURSE_ANDREA_ORG_TOKEN
    })

    it("isEnabled returns true when fully configured and enabled", () => {
      configure({ ...validConfig(), enabled: true })
      expect(isEnabled()).toBe(true)
    })
  })

  describe("validation (Sprint B D2 — silent-degrade parity)", () => {
    // Pre-Sprint-B these tests asserted Node throws on misconfig.
    // The cross-runtime parity contract
    // (docs/sdk/payload-format.md §6) requires silent-degrade
    // instead, matching Ruby/Python/Go. Each case now asserts:
    //   - configure() does NOT throw
    //   - isEnabled() returns false
    //   - the validation failure was written to stderr as a warn
    let stderrSpy: jest.SpyInstance

    beforeEach(() => {
      stderrSpy = jest.spyOn(process.stderr, "write").mockImplementation(() => true)
    })
    afterEach(() => stderrSpy.mockRestore())

    it("silent-degrades when orgToken is missing", () => {
      expect(() => configure({ workspaceSlug: "ok", environment: "development" })).not.toThrow()
      expect(isEnabled()).toBe(false)
      expect(stderrSpy).toHaveBeenCalledWith(expect.stringMatching(/orgToken is required/))
    })

    it("silent-degrades when workspaceSlug is missing", () => {
      expect(() => configure({ orgToken: "x", environment: "development" })).not.toThrow()
      expect(isEnabled()).toBe(false)
      expect(stderrSpy).toHaveBeenCalledWith(expect.stringMatching(/workspaceSlug is required/))
    })

    it("silent-degrades when environment is unsupported", () => {
      expect(() => configure({ ...validConfig(), environment: "qa" as never })).not.toThrow()
      expect(isEnabled()).toBe(false)
      expect(stderrSpy).toHaveBeenCalledWith(expect.stringMatching(/environment must be one of/))
    })

    it("silent-degrades when workspaceSlug is invalid format", () => {
      expect(() => configure({ ...validConfig(), workspaceSlug: "Bad_Slug" })).not.toThrow()
      expect(isEnabled()).toBe(false)
      expect(stderrSpy).toHaveBeenCalledWith(expect.stringMatching(/workspaceSlug.*invalid.*lowercase/))
    })
  })

  describe("migration errors", () => {
    it.each(["apiKey", "token", "ingestToken"])("throws MigrationError for legacy field %s", (field) => {
      expect(() => configure({ [field]: "x" } as never)).toThrow(MigrationError)
      expect(() => configure({ [field]: "x" } as never)).toThrow(/no longer supported/)
    })

    it("MigrationError descends from ConfigurationError", () => {
      const err = new MigrationError("test")
      expect(err).toBeInstanceOf(ConfigurationError)
    })
  })
})
