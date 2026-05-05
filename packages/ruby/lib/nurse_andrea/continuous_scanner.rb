# PRIVACY: Same guarantees as ManagedServiceScanner — only derived
# metadata is transmitted, never raw env values. See
# DATA_PRIVACY_POLICY.rb for the full policy.
#
# Periodically re-runs the env-based discovery scan so dependencies
# added after boot (new env vars, services attached to running
# instances, configuration reloads) eventually surface as
# discoveries on the workspace dashboard.
#
# Properties guaranteed by the contract below:
#   * Non-blocking — runs on a dedicated background thread, never on
#     the request path.
#   * Bounded — only one thread; calling start! twice is a no-op.
#   * Fail-safe — any error inside the scan is swallowed; the host
#     application never crashes from a discovery error.
#   * Self-aware — short-circuits when SelfFilter.platform_self?
#     because every URL would be NurseAndrea's own infra.
#   * Stoppable — explicit stop! signals the thread to exit at the
#     next sleep boundary; configuration.disable_continuous_scan
#     prevents start! from creating the thread at all.
#
# Fork-safety note: the thread does NOT survive Process._fork (Puma
# clustered mode, Sidekiq workers). If the host forks after boot, the
# parent's scanner thread is gone and a new one is not auto-started.
# Address in a follow-up if it shows up in practice — for one-off
# webservers and single-process deployments the current design is
# sufficient.

module NurseAndrea
  class ContinuousScanner
    @thread = nil
    @stop   = false
    @mutex  = Mutex.new

    class << self
      attr_reader :thread

      def start!
        @mutex.synchronize do
          return if @thread&.alive?
          return if NurseAndrea.config.disable_continuous_scan

          @stop   = false
          @thread = Thread.new { run_loop }
          @thread.name = "nurse_andrea_continuous_scanner"
        end
      end

      def stop!
        @mutex.synchronize do
          @stop = true
        end
        @thread&.wakeup rescue nil
        @thread&.join(2)
        @thread = nil
      end

      def running?
        @thread&.alive? == true
      end

      # Public so specs can call it without spinning the loop.
      def rescan_safely
        return if NurseAndrea::SelfFilter.platform_self?

        discoveries = NurseAndrea::ManagedServiceScanner.scan
        return if discoveries.empty?

        # Only push new items — ManagedServiceScanner already dedups
        # by (type, tech, provider) within a single call, so we just
        # need to avoid resubmitting items already queued for the
        # current flush.
        existing_keys = NurseAndrea.component_discoveries.map { |d| [ d[:type], d[:tech], d[:provider] ] }
        discoveries.reject! { |d| existing_keys.include?([ d[:type], d[:tech], d[:provider] ]) }
        NurseAndrea.component_discoveries.concat(discoveries) if discoveries.any?
      rescue => e
        NurseAndrea.debug("[ContinuousScanner] error: #{e.class}: #{e.message}")
      end

      private

      def run_loop
        interval = NurseAndrea.config.continuous_scan_interval
        until @stop
          sleep interval
          break if @stop
          rescan_safely
        end
      end
    end
  end
end
