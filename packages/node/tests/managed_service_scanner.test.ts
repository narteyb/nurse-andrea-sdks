import { scanManagedServices } from "../src/managed_service_scanner"

describe("ManagedServiceScanner", () => {
  const saved: Record<string, string | undefined> = {}
  const VARS = ["DATABASE_URL", "REDIS_URL", "RABBITMQ_URL"]

  beforeEach(() => {
    VARS.forEach(v => { saved[v] = process.env[v]; delete process.env[v] })
  })
  afterEach(() => {
    VARS.forEach(v => { delete process.env[v]; if (saved[v] !== undefined) process.env[v] = saved[v] })
  })

  test("returns postgresql discovery for DATABASE_URL=postgres://...", () => {
    process.env.DATABASE_URL = "postgres://user:secret@host:5432/db"
    const results = scanManagedServices()
    expect(results).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ type: "database", tech: "postgresql", variable_name: "DATABASE_URL" })
      ])
    )
  })

  test("returns redis discovery for REDIS_URL", () => {
    process.env.REDIS_URL = "redis://default:secret@host:6379"
    const results = scanManagedServices()
    expect(results).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ type: "cache", tech: "redis", variable_name: "REDIS_URL" })
      ])
    )
  })

  test("returns empty for no env vars", () => {
    expect(scanManagedServices()).toEqual([])
  })

  test("does not ship raw URL value in discovery payload", () => {
    process.env.DATABASE_URL = "postgres://user:secret_password@db.railway.internal:5432/mydb"
    const results = scanManagedServices()
    const flat = JSON.stringify(results)
    expect(flat).not.toContain("secret_password")
    expect(flat).not.toContain("db.railway.internal")
    expect(flat).not.toContain("5432")
    expect(flat).not.toContain("mydb")
  })
})
