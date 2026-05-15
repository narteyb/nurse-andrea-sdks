import { getConfig, ingestUrl, metricsUrl, isEnabled } from "./configuration"
import { flushDiscoveries } from "./discovery"
import { detectPlatform } from "./platform_detector"
import { isValidSlug, SLUG_RULES_HUMAN } from "./slug-validator"
import { SDK_VERSION, SDK_LANGUAGE } from "./version"

export interface LogEntry {
  level: "debug" | "info" | "warn" | "error"
  message: string
  timestamp: string
  service: string
  metadata?: Record<string, unknown>
}

export interface MetricEntry {
  name: string
  value: number
  unit: string
  timestamp: string
  tags: Record<string, string>
}

const REJECTION_WARNING_THRESHOLD = 5
const REJECTION_STATUSES = new Set([401, 403, 422, 429])

class NurseAndreaClient {
  private logQueue: LogEntry[] = []
  private metricQueue: MetricEntry[] = []
  private timer: ReturnType<typeof setInterval> | null = null

  private consecutiveRejections = 0
  private warnedForError: string | null = null

  start(): void {
    if (this.timer) return
    if (!isEnabled()) return
    const config = getConfig()
    this.timer = setInterval(() => {
      this.collectProcessMemory()
      this.flush()
    }, config.flushIntervalMs)
    if (this.timer.unref) this.timer.unref()
  }

  stop(): void {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
    this.flush()
  }

  resetRejectionState(): void {
    this.consecutiveRejections = 0
    this.warnedForError = null
  }

  private collectProcessMemory(): void {
    try {
      const rss = process.memoryUsage().rss
      this.enqueueMetric({ name: "process.memory.rss", value: rss, unit: "bytes" })
    } catch { /* never crash the host app */ }
  }

  enqueueLog(entry: Omit<LogEntry, "service" | "timestamp">): void {
    if (!isEnabled()) return
    this.logQueue.push({
      ...entry,
      service: getConfig().serviceName,
      timestamp: new Date().toISOString(),
    })
    if (this.logQueue.length >= getConfig().batchSize) this.flush()
  }

  enqueueMetric(
    entry: Omit<MetricEntry, "timestamp" | "tags"> & {
      tags?: Record<string, string>
    }
  ): void {
    if (!isEnabled()) return
    this.metricQueue.push({
      ...entry,
      tags: { service: getConfig().serviceName, ...(entry.tags ?? {}) },
      timestamp: new Date().toISOString(),
    })
    if (this.metricQueue.length >= getConfig().batchSize) this.flush()
  }

  buildHeaders(): Record<string, string> {
    const config = getConfig()
    return {
      "Content-Type":              "application/json",
      "Authorization":             `Bearer ${config.orgToken}`,
      "X-NurseAndrea-Workspace":   config.workspaceSlug,
      "X-NurseAndrea-Environment": config.environment,
      "X-NurseAndrea-SDK":         `${SDK_LANGUAGE}/${SDK_VERSION}`,
    }
  }

  async handleResponse(res: Response, url: string): Promise<void> {
    if (res.status >= 200 && res.status < 300) {
      this.consecutiveRejections = 0
      this.warnedForError = null
      return
    }

    if (!REJECTION_STATUSES.has(res.status)) {
      process.stderr.write(`[NurseAndrea] POST ${url} → ${res.status}\n`)
      return
    }

    this.consecutiveRejections += 1
    if (this.consecutiveRejections < REJECTION_WARNING_THRESHOLD) return

    let body: { error?: string; message?: string } = {}
    try {
      body = (await res.clone().json()) as { error?: string; message?: string }
    } catch { /* body wasn't JSON */ }

    const errorCode = body.error ?? ""
    if (this.warnedForError === errorCode) return
    this.warnedForError = errorCode

    process.stderr.write(
      `[NurseAndrea] Ingest rejected (${REJECTION_WARNING_THRESHOLD}+ consecutive). ` +
      `Status: ${res.status} Error: ${errorCode || "(unknown)"}. ` +
      `${guidanceFor(errorCode, getConfig())}` +
      (body.message ? ` Details: ${body.message}` : "") +
      "\n"
    )
  }

  private async flush(): Promise<void> {
    if (!isEnabled()) return

    const logs = this.logQueue.splice(0)
    const metrics = this.metricQueue.splice(0)
    const config = getConfig()

    const headers = this.buildHeaders()

    try {
      if (logs.length > 0) {
        const url = ingestUrl()
        const res = await fetch(url, {
          method: "POST",
          headers,
          body: JSON.stringify({
            services:     [config.serviceName].filter(Boolean),
            sdk_version:  SDK_VERSION,
            sdk_language: SDK_LANGUAGE,
            logs: logs.map(l => ({
              level:       l.level,
              message:     l.message,
              occurred_at: l.timestamp,
              source:      l.service,
              payload:     l.metadata ?? {},
            })),
          }),
        })
        await this.handleResponse(res, url)
      }

      if (metrics.length > 0) {
        const url = metricsUrl()
        const payload: Record<string, unknown> = {
          // Sprint B D2 — metric entries serialize with
          // `occurred_at` (canonical wire key per
          // docs/sdk/payload-format.md §4.2). Pre-Sprint-B Node
          // spread the in-memory MetricEntry directly, leaking the
          // internal `timestamp` property onto the wire and
          // diverging from Ruby + Python.
          metrics: metrics.map(m => ({
            name:        m.name,
            value:       m.value,
            unit:        m.unit,
            occurred_at: m.timestamp,
            tags:        m.tags,
          })),
          platform:     detectPlatform(),
          sdk_version:  SDK_VERSION,
          sdk_language: SDK_LANGUAGE,
        }
        const componentDiscoveries = flushDiscoveries()
        if (componentDiscoveries.length > 0) {
          payload.component_discoveries = componentDiscoveries
        }
        const res = await fetch(url, {
          method: "POST",
          headers,
          body: JSON.stringify(payload),
        })
        await this.handleResponse(res, url)
      }
    } catch (err) {
      process.stderr.write(`[NurseAndrea] Flush failed: ${(err as Error).message}\n`)
      this.logQueue.unshift(...logs)
      this.metricQueue.unshift(...metrics)
    }
  }
}

function guidanceFor(errorCode: string, config: { environment: string; host: string }): string {
  switch (errorCode) {
    case "invalid_org_token":
      return "Check NURSE_ANDREA_ORG_TOKEN."
    case "workspace_rejected":
      return "Restore the workspace in the dashboard or change workspaceSlug."
    case "workspace_limit_exceeded":
      return "Org has reached its workspace limit. Reject unused workspaces or upgrade plan."
    case "auto_create_disabled":
      return "Auto-create disabled. Create the workspace explicitly in the dashboard before ingesting."
    case "environment_not_accepted_by_this_install":
      return `Environment '${config.environment}' not accepted by NurseAndrea at ${config.host}. Check NURSE_ANDREA_HOST.`
    case "invalid_workspace_slug":
      return SLUG_RULES_HUMAN
    case "similar_slug_exists":
      return "A similar slug already exists in this org. Did you mean an existing one?"
    case "creation_rate_limit_exceeded":
    case "rate_limited":
      return "Workspace creation rate limit hit. Existing workspaces still ingesting normally."
    default:
      return ""
  }
}

export const client = new NurseAndreaClient()
// Re-exported helper for tests/integration:
export { isValidSlug }
