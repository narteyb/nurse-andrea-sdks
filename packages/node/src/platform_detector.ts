// PRIVACY POLICY: Only platform name derived from env var presence.
// No env var values are read or transmitted.

const PLATFORM_SIGNALS = [
  { name: "railway",      vars: ["RAILWAY_ENVIRONMENT", "RAILWAY_SERVICE_NAME"] },
  { name: "render",       vars: ["RENDER", "RENDER_SERVICE_ID"] },
  { name: "fly",          vars: ["FLY_APP_NAME", "FLY_REGION"] },
  { name: "heroku",       vars: ["DYNO", "HEROKU_APP_NAME"] },
  { name: "digitalocean", vars: ["DIGITALOCEAN_APP_NAME"] },
  { name: "vercel",       vars: ["VERCEL", "VERCEL_ENV"] },
] as const

export function detectPlatform(): string {
  for (const { name, vars } of PLATFORM_SIGNALS) {
    if (vars.some(v => v in process.env)) return name
  }
  return "unknown"
}
