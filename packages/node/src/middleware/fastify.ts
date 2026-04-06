import { client } from "../client"
import { isEnabled, getConfig } from "../configuration"

// Minimal type declarations — fastify is a peer dependency
interface FastifyRequest { method: string; url: string; routeOptions?: { url?: string } }
interface FastifyReply { statusCode: number; elapsedTime: number }
interface FastifyInstance { addHook(name: string, fn: (req: FastifyRequest, reply: FastifyReply) => Promise<void>): void }

export async function nurseAndreaFastify(
  fastify: FastifyInstance
): Promise<void> {
  fastify.addHook(
    "onResponse",
    async (request: FastifyRequest, reply: FastifyReply) => {
      if (!isEnabled()) return

      const durationMs = Math.round(reply.elapsedTime)
      const route = request.routeOptions?.url ?? request.url

      client.enqueueMetric({
        name: "http.request.duration",
        value: durationMs,
        unit: "ms",
        tags: {
          method: request.method,
          route: route,
          status_code: String(reply.statusCode),
          service: getConfig().serviceName,
        },
      })

      if (reply.statusCode >= 400) {
        client.enqueueLog({
          level: reply.statusCode >= 500 ? "error" : "warn",
          message: `${request.method} ${route} → ${reply.statusCode} (${durationMs}ms)`,
          metadata: {
            method: request.method,
            route: route,
            status_code: reply.statusCode,
            duration_ms: durationMs,
          },
        })
      }
    }
  )
}
