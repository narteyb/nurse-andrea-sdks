// PRIVACY POLICY: Only queue names and durations recorded.
import { registerDiscovery } from "../discovery"

let discovered = false

export function attachBullMQ(worker: any): void {
  if (!worker?.on) return

  const discover = () => {
    if (!discovered) {
      discovered = true
      const conn = worker.opts?.connection || {}
      registerDiscovery(
        { type: "queue", tech: "bullmq", source: "hook_subscription" },
        { host: conn.host, url: conn.url },
      )
    }
  }

  worker.on("active", discover)
  worker.on("completed", discover)
  worker.on("failed", discover)
}
