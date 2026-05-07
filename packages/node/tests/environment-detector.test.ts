import { detectEnvironment, _resetWarning } from "../src/environment-detector"

describe("environment-detector", () => {
  let prev: string | undefined
  let stderrSpy: jest.SpyInstance

  beforeEach(() => {
    prev = process.env.NODE_ENV
    delete process.env.NODE_ENV
    _resetWarning()
    stderrSpy = jest.spyOn(process.stderr, "write").mockImplementation(() => true)
  })

  afterEach(() => {
    if (prev === undefined) delete process.env.NODE_ENV
    else process.env.NODE_ENV = prev
    stderrSpy.mockRestore()
  })

  it("falls back to 'production' when NODE_ENV is unset", () => {
    expect(detectEnvironment()).toBe("production")
  })

  it.each(["production", "staging", "development"])(
    "returns the value for supported NODE_ENV=%s",
    (value) => {
      process.env.NODE_ENV = value
      expect(detectEnvironment()).toBe(value)
    }
  )

  it("falls back to 'production' for unsupported NODE_ENV like 'test'", () => {
    process.env.NODE_ENV = "test"
    expect(detectEnvironment()).toBe("production")
  })

  it("warns once for an unsupported value, not on subsequent calls", () => {
    process.env.NODE_ENV = "qa"
    detectEnvironment()
    detectEnvironment()
    detectEnvironment()
    const writes = stderrSpy.mock.calls
      .map(args => String(args[0]))
      .filter(s => s.includes("[NurseAndrea]"))
    expect(writes).toHaveLength(1)
  })
})
