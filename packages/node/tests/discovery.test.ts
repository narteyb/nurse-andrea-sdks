import { discoveries, registerDiscovery, clearDiscoveries, flushDiscoveries, selfReferential } from "../src/discovery"

describe("Discovery registry", () => {
  beforeEach(() => clearDiscoveries())

  test("registerDiscovery adds to the list", () => {
    registerDiscovery({ type: "database", tech: "postgresql", source: "hook_subscription" })
    expect(discoveries()).toHaveLength(1)
    expect(discoveries()[0]).toEqual(
      expect.objectContaining({ type: "database", tech: "postgresql" })
    )
  })

  test("deduplicates by type+tech", () => {
    registerDiscovery({ type: "database", tech: "postgresql", source: "hook_subscription" })
    registerDiscovery({ type: "database", tech: "postgresql", source: "env_detection" })
    expect(discoveries()).toHaveLength(1)
  })

  test("allows different type+tech pairs", () => {
    registerDiscovery({ type: "database", tech: "postgresql", source: "hook_subscription" })
    registerDiscovery({ type: "cache", tech: "redis", source: "env_detection" })
    expect(discoveries()).toHaveLength(2)
  })

  test("flushDiscoveries returns and clears", () => {
    registerDiscovery({ type: "cache", tech: "redis", source: "env_detection" })
    const flushed = flushDiscoveries()
    expect(flushed).toHaveLength(1)
    expect(discoveries()).toHaveLength(0)
  })

  test("discovery never contains raw URL data", () => {
    registerDiscovery({ type: "database", tech: "postgresql", source: "env_detection", variable_name: "DATABASE_URL" })
    const flat = JSON.stringify(discoveries())
    expect(flat).not.toContain("postgres://")
    expect(flat).not.toContain("password")
  })
})

describe("Self-filter", () => {
  beforeEach(() => clearDiscoveries())

  describe("selfReferential", () => {
    test("returns false when metadata is null/undefined", () => {
      expect(selfReferential(undefined)).toBe(false)
      expect(selfReferential(null)).toBe(false)
    })

    test("returns false when no fields populated", () => {
      expect(selfReferential({})).toBe(false)
    })

    test("returns false for an external customer database", () => {
      expect(selfReferential({ host: "shop-db.aws.com", dbName: "shop_production" })).toBe(false)
    })

    test("returns true when host contains 'nurseandrea'", () => {
      expect(selfReferential({ host: "db.nurseandrea.io" })).toBe(true)
    })

    test("returns true when dbName contains 'nurse_andrea'", () => {
      expect(selfReferential({ dbName: "nurse_andrea_development" })).toBe(true)
    })

    test("returns true when url contains 'nurse-andrea'", () => {
      expect(selfReferential({ url: "redis://cache.nurse-andrea.internal:6379" })).toBe(true)
    })

    test("matches case-insensitively", () => {
      expect(selfReferential({ host: "DB.NurseAndrea.IO" })).toBe(true)
    })
  })

  describe("registerDiscovery with metadata", () => {
    test("does not emit when metadata is self-referential", () => {
      registerDiscovery(
        { type: "database", tech: "postgresql", source: "hook_subscription" },
        { dbName: "nurse_andrea_development" },
      )
      expect(discoveries()).toHaveLength(0)
    })

    test("emits when metadata points at an external host", () => {
      registerDiscovery(
        { type: "database", tech: "postgresql", source: "hook_subscription" },
        { host: "rds.aws.com", dbName: "shop" },
      )
      expect(discoveries()).toHaveLength(1)
    })

    test("emits when metadata is omitted", () => {
      registerDiscovery({ type: "cache", tech: "redis", source: "hook_subscription" })
      expect(discoveries()).toHaveLength(1)
    })
  })
})
