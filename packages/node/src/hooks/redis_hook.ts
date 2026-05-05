// PRIVACY POLICY: Only command names recorded. No key values or connection strings.
import { registerDiscovery } from "../discovery"

let discovered = false

export function attachRedis(client: any): void {
  if (!client?.on) return

  client.on("connect", () => {
    if (!discovered) {
      discovered = true
      // ioredis stores host on .options; node-redis stores the URL on
      // .options.url. Probe both — either tells us if the cache lives
      // on NurseAndrea's own infrastructure.
      const opts = client.options || {}
      registerDiscovery(
        { type: "cache", tech: "redis", source: "hook_subscription" },
        { host: opts.host, url: opts.url },
      )
    }
  })
}
