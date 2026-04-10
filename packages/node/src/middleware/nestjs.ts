import type { Request, Response, NextFunction } from "express"
import { client } from "../client"
import { isEnabled, getConfig } from "../configuration"
import { generateTraceId, generateSpanId, enqueueSpan } from "../tracing/exporter"

// NestJS middleware — injectable class
// Usage: consumer.apply(NurseAndreaMiddleware).forRoutes("*")
export class NurseAndreaMiddleware {
  use(req: Request, res: Response, next: NextFunction): void {
    if (!isEnabled()) {
      next()
      return
    }

    const startedAt = Date.now()
    const startNs = BigInt(Date.now()) * 1_000_000n
    const traceId = generateTraceId()
    const spanId = generateSpanId()

    res.on("finish", () => {
      const durationMs = Date.now() - startedAt
      const endNs = BigInt(Date.now()) * 1_000_000n
      const route = req.route?.path ?? req.path

      enqueueSpan({
        traceId, spanId, parentSpanId: "",
        name: `${req.method} ${route}`, kind: 2,
        startTimeUnixNano: startNs.toString(), endTimeUnixNano: endNs.toString(),
        status: { code: res.statusCode >= 500 ? 2 : 1, message: res.statusCode >= 500 ? `HTTP ${res.statusCode}` : "" },
        attributes: [
          { key: "http.method", value: { stringValue: req.method } },
          { key: "http.url", value: { stringValue: route } },
          { key: "http.status_code", value: { intValue: res.statusCode } },
        ],
        events: [],
      })

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
