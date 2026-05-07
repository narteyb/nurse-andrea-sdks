import { nurseAndreaExpress } from "../src/middleware/express"
import { configure } from "../src/configuration"
import { client } from "../src/client"

configure({
  orgToken: "org_test_token",
  workspaceSlug: "checkout",
  environment: "development",
  enabled: true,
  flushIntervalMs: 99999,
})

afterEach(() => jest.restoreAllMocks())

describe("Express middleware", () => {
  it("enqueues a metric on response finish", () => {
    const enqueueMetric = jest.spyOn(client, "enqueueMetric")
    const middleware = nurseAndreaExpress()

    const req = { method: "GET", path: "/test", route: { path: "/test" } } as any
    const res = { statusCode: 200, on: jest.fn() } as any
    const next = jest.fn()

    middleware(req, res, next)
    expect(next).toHaveBeenCalled()
    expect(res.on).toHaveBeenCalledWith("finish", expect.any(Function))

    const finishHandler = res.on.mock.calls[0][1]
    finishHandler()
    expect(enqueueMetric).toHaveBeenCalledWith(
      expect.objectContaining({
        name: "http.server.duration",
        tags: expect.objectContaining({
          http_method: "GET",
          http_path:   "/test",
          http_status: "200",
        }),
      })
    )
  })

  it("enqueues an error log for 5xx responses", () => {
    const enqueueLog = jest.spyOn(client, "enqueueLog")
    const middleware = nurseAndreaExpress()

    const req = { method: "POST", path: "/fail", route: { path: "/fail" } } as any
    const res = { statusCode: 500, on: jest.fn() } as any

    middleware(req, res, jest.fn())
    const finishHandler = res.on.mock.calls[0][1]
    finishHandler()

    expect(enqueueLog).toHaveBeenCalledWith(
      expect.objectContaining({ level: "error" })
    )
  })

  it("does not enqueue for successful responses", () => {
    const enqueueLog = jest.spyOn(client, "enqueueLog")
    const middleware = nurseAndreaExpress()

    const req = { method: "GET", path: "/ok", route: { path: "/ok" } } as any
    const res = { statusCode: 200, on: jest.fn() } as any

    middleware(req, res, jest.fn())
    const finishHandler = res.on.mock.calls[0][1]
    finishHandler()

    expect(enqueueLog).not.toHaveBeenCalled()
  })
})
