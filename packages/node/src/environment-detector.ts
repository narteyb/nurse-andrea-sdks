export const SUPPORTED_ENVIRONMENTS = ["production", "staging", "development"] as const
export type Environment = (typeof SUPPORTED_ENVIRONMENTS)[number]

let warned = false

export function detectEnvironment(): Environment {
  const raw = process.env.NODE_ENV
  if (!raw) return "production"

  if ((SUPPORTED_ENVIRONMENTS as readonly string[]).includes(raw)) {
    return raw as Environment
  }

  if (!warned) {
    warned = true
    process.stderr.write(
      `[NurseAndrea] Detected NODE_ENV '${raw}' is not in the supported set ` +
      `${JSON.stringify(SUPPORTED_ENVIRONMENTS)}. Falling back to 'production'.\n`
    )
  }
  return "production"
}

export function _resetWarning(): void {
  warned = false
}
