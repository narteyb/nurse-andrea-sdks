import { sanitizeTech, techFromUrl } from "../src/sanitizer"

describe("Sanitizer", () => {
  describe("sanitizeTech", () => {
    test("normalizes postgres → postgresql", () => {
      expect(sanitizeTech("postgres")).toBe("postgresql")
    })
    test("normalizes pg → postgresql", () => {
      expect(sanitizeTech("pg")).toBe("postgresql")
    })
    test("normalizes ioredis → redis", () => {
      expect(sanitizeTech("ioredis")).toBe("redis")
    })
    test("normalizes mysql2 → mysql", () => {
      expect(sanitizeTech("mysql2")).toBe("mysql")
    })
    test("returns null for unknown tech", () => {
      expect(sanitizeTech("clickhouse")).toBeNull()
    })
    test("returns null for empty string", () => {
      expect(sanitizeTech("")).toBeNull()
    })
    test("returns null for null/undefined", () => {
      expect(sanitizeTech(null as any)).toBeNull()
      expect(sanitizeTech(undefined as any)).toBeNull()
    })
  })

  describe("techFromUrl", () => {
    test("extracts postgresql from postgres:// URL", () => {
      expect(techFromUrl("postgres://user:pass@host:5432/db")).toBe("postgresql")
    })
    test("extracts redis from redis:// URL", () => {
      expect(techFromUrl("redis://default:pass@host:6379")).toBe("redis")
    })
    test("returns null for http:// URL", () => {
      expect(techFromUrl("http://example.com")).toBeNull()
    })
    test("returns null for malformed URL", () => {
      expect(techFromUrl("not-a-url")).toBeNull()
    })
  })
})
