import type { Request, Response, NextFunction } from "express"
import { client } from "../client"
import { isEnabled, getConfig } from "../configuration"

export function nurseAndreaExpress() {
  return function (req: Request, res: Response, next: NextFunction): void {
    if (!isEnabled()) {
      next()
      return
    }

    const startedAt = Date.now()

    res.on("finish", () => {
      const durationMs = Date.now() - startedAt
      const route = (req.route?.path ?? req.path) as string

      client.enqueueMetric({
        name: "http.server.duration",
        value: durationMs,
        unit: "ms",
        tags: {
          http_method: req.method,
          http_path: route,
          http_status: String(res.statusCode),
          service: getConfig().serviceName,
        },
      })

      if (res.statusCode >= 400) {
        client.enqueueLog({
          level: res.statusCode >= 500 ? "error" : "warn",
          message: `${req.method} ${route} → ${res.statusCode} (${durationMs}ms)`,
          metadata: {
            http_method: req.method,
            http_path: route,
            http_status: res.statusCode,
            duration_ms: durationMs,
          },
        })
      }
    })

    next()
  }
}
