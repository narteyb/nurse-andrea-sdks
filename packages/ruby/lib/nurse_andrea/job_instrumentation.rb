require "active_support/concern"

module NurseAndrea
  module JobInstrumentation
    extend ActiveSupport::Concern

    included do
      around_perform :nurseandrea_instrument_job
    end

    private

    def nurseandrea_instrument_job
      return yield unless NurseAndrea.config.enabled?

      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      status = "completed"
      error_class = nil
      error_message = nil

      begin
        yield
      rescue => e
        status = "failed"
        error_class = e.class.name
        error_message = e.message.to_s[0, 500]
        raise
      ensure
        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round(2)

        NurseAndrea::MetricsShipper.instance.enqueue(
          name:      "job.perform",
          value:     duration_ms,
          unit:      "ms",
          timestamp: Time.now.utc.iso8601(3),
          tags:      {
            job_class:     self.class.name,
            queue_name:    queue_name,
            status:        status,
            error_class:   error_class,
            attempts:      executions,
            priority:      priority
          }.compact
        )

        if NurseAndrea.config.debug
          warn "[NurseAndrea::JobInstrumentation] #{self.class.name} #{status} in #{duration_ms}ms"
        end
      end
    end
  end
end
