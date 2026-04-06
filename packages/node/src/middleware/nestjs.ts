import type { Request, Response, NextFunction } from "express"
import { client } from "../client"
import { isEnabled, getConfig } from "../configuration"

// NestJS middleware — injectable class
// Usage: consumer.apply(NurseAndreaMiddleware).forRoutes("*")
export class NurseAndreaMiddleware {
  use(req: Request, res: Response, next: NextFunction): void {
    if (!isEnabled()) {
      next()
      return
    }

    const startedAt = Date.now()

    res.on("finish", () => {
      const durationMs = Date.now() - startedAt
      const route = req.route?.path ?? req.path

      client.enqueueMetric({
        name: "http.request.duration",
        value: durationMs,
        unit: "ms",
        tags: {
          method: req.method,
          route: route,
          status_code: String(res.statusCode),
          service: getConfig().serviceName,
        },
      })

      if (res.statusCode >= 400) {
        client.enqueueLog({
          level: res.statusCode >= 500 ? "error" : "warn",
          message: `${req.method} ${route} → ${res.statusCode} (${durationMs}ms)`,
          metadata: {
            method: req.method,
            route: route,
            status_code: res.statusCode,
            duration_ms: durationMs,
          },
        })
      }
    })

    next()
  }
}
