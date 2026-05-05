import { detectPlatform } from "../src/platform_detector"

describe("PlatformDetector", () => {
  const saved: Record<string, string | undefined> = {}
  const VARS = ["RAILWAY_ENVIRONMENT", "RENDER", "FLY_APP_NAME", "DYNO", "DIGITALOCEAN_APP_NAME", "VERCEL"]

  beforeEach(() => {
    VARS.forEach(v => { saved[v] = process.env[v]; delete process.env[v] })
  })
  afterEach(() => {
    VARS.forEach(v => { delete process.env[v]; if (saved[v] !== undefined) process.env[v] = saved[v] })
  })

  test("detects railway from RAILWAY_ENVIRONMENT", () => {
    process.env.RAILWAY_ENVIRONMENT = "production"
    expect(detectPlatform()).toBe("railway")
  })

  test("detects render from RENDER", () => {
    process.env.RENDER = "true"
    expect(detectPlatform()).toBe("render")
  })

  test("detects fly from FLY_APP_NAME", () => {
    process.env.FLY_APP_NAME = "my-app"
    expect(detectPlatform()).toBe("fly")
  })

  test("returns unknown when no platform env vars present", () => {
    expect(detectPlatform()).toBe("unknown")
  })
})
