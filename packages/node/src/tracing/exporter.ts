import { getConfig, isEnabled } from "../configuration"
import crypto from "crypto"

interface SpanData {
  traceId: string
  spanId: string
  parentSpanId: string
  name: string
  kind: number
  startTimeUnixNano: string
  endTimeUnixNano: string
  status: { code: number; message: string }
  attributes: Array<{ key: string; value: Record<string, unknown> }>
  events: unknown[]
}

const queue: SpanData[] = []
let timer: ReturnType<typeof setInterval> | null = null

export function generateTraceId(): string {
  return crypto.randomBytes(16).toString("hex")
}

export function generateSpanId(): string {
  return crypto.randomBytes(8).toString("hex")
}

export function enqueueSpan(span: SpanData): void {
  if (!isEnabled()) return
  queue.push(span)
  if (queue.length >= 100) flush()
}

export function startTraceExporter(): void {
  if (timer) return
  timer = setInterval(flush, 5000)
  if (timer.unref) timer.unref()
}

export function stopTraceExporter(): void {
  if (timer) {
    clearInterval(timer)
    timer = null
  }
  flush()
}

async function flush(): Promise<void> {
  if (!isEnabled() || queue.length === 0) return
  const spans = queue.splice(0)
  const config = getConfig()

  const payload = {
    resourceSpans: [{
      resource: {
        attributes: [
          { key: "service.name", value: { stringValue: config.serviceName } }
        ]
      },
      scopeSpans: [{ spans }]
    }]
  }

  const url = `${config.host.replace(/\/$/, "")}/api/v1/traces`
  try {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type":              "application/json",
        "Authorization":             `Bearer ${config.orgToken}`,
        "X-NurseAndrea-Workspace":   config.workspaceSlug,
        "X-NurseAndrea-Environment": config.environment,
      },
      body: JSON.stringify(payload),
    })
    if (!res.ok) {
      process.stderr.write(`[NurseAndrea] Trace export → ${res.status}\n`)
    }
  } catch (err) {
    process.stderr.write(`[NurseAndrea] Trace export failed: ${(err as Error).message}\n`)
  }
}
