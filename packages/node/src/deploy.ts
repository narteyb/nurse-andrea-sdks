import { getConfig, isEnabled } from "./configuration"
import { SDK_LANGUAGE, SDK_VERSION } from "./version"

const DESCRIPTION_LIMIT = 500

export interface DeployPayload {
  version:     string
  deployer?:   string | null
  environment?: string
  description?: string | null
}

function deployUrl(): string {
  return `${getConfig().host.replace(/\/$/, "")}/api/v1/deploy`
}

// Public: ship a deploy event to the NurseAndrea backend so the
// dashboard can render it as a vertical marker on time-series charts
// and as a chip in the recent-deploys strip.
//
// Fire-and-forget: any failure (no token, network error, non-2xx) is
// logged and swallowed so the host application never crashes from a
// deploy notification.
export async function deploy(input: DeployPayload): Promise<boolean> {
  if (!isEnabled()) return false
  if (!input.version || String(input.version).trim() === "") return false

  const description = typeof input.description === "string"
    ? input.description.slice(0, DESCRIPTION_LIMIT)
    : input.description

  const body: Record<string, unknown> = {
    version:     String(input.version),
    deployer:    input.deployer    ?? null,
    environment: input.environment ?? "production",
    description: description       ?? null,
    deployed_at: new Date().toISOString(),
  }

  try {
    const config = getConfig()
    const res = await fetch(deployUrl(), {
      method:  "POST",
      headers: {
        "Content-Type":              "application/json",
        "Authorization":             `Bearer ${config.orgToken}`,
        "X-NurseAndrea-Workspace":   config.workspaceSlug,
        "X-NurseAndrea-Environment": config.environment,
        // Sprint B D2 — added to align with Ruby's HttpClient
        // (which already attached this header to every POST,
        // including deploy). Per docs/sdk/payload-format.md §5.2.
        "X-NurseAndrea-SDK":         `${SDK_LANGUAGE}/${SDK_VERSION}`,
        // Sprint C — replay-mitigation timestamp.
        "X-NurseAndrea-Timestamp":   Math.floor(Date.now() / 1000).toString(),
      },
      body: JSON.stringify(body),
    })
    if (!res.ok) {
      process.stderr.write(`[NurseAndrea] deploy() POST ${deployUrl()} → ${res.status}\n`)
      return false
    }
    return true
  } catch (err) {
    process.stderr.write(`[NurseAndrea] deploy() error: ${(err as Error).message}\n`)
    return false
  }
}
