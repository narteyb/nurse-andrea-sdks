module NurseAndrea
  class QuerySubscriber
    SKIP_PATTERN = /\A(SHOW|SET|PRAGMA|SELECT.*schema_migrations|BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE|SELECT version)/i
    SKIP_CONNECTIONS = %w[ClickhouseActiverecord Clickhouse].freeze
    SLOW_THRESHOLD_MS = 100

    def self.subscribe!
      ActiveSupport::Notifications.subscribe("sql.active_record") do |name, start, finish, id, payload|
        next if payload[:name] == "SCHEMA"

        # Only instrument PostgreSQL queries — skip ClickHouse
        conn = payload[:connection]
        conn_name = conn.is_a?(Class) ? conn.name.to_s : conn.class.name.to_s
        next if SKIP_CONNECTIONS.any? { |c| conn_name.include?(c) }
        # Also skip by adapter name if available
        next if payload[:connection_id].to_s.include?("clickhouse")

        # Skip queries targeting ClickHouse tables
        sql_check = payload[:sql].to_s
        next if sql_check.match?(/\b(metric_points|log_entries|job_metrics|spans)\b/i)

        sql = payload[:sql].to_s.strip
        next if sql.empty?
        next if sql.match?(SKIP_PATTERN)

        duration_ms = ((finish - start) * 1000).round(2)
        timestamp   = finish.utc.iso8601(3)

        # Always ship slow queries
        if duration_ms >= SLOW_THRESHOLD_MS
          LogShipper.instance.enqueue(
            level:     "warn",
            message:   "SLOW QUERY took #{duration_ms.round}ms: #{sql.first(2000)}",
            timestamp: timestamp
          )
        end

        # Sample 10% of all queries for frequency tracking
        if rand < 0.1
          LogShipper.instance.enqueue(
            level:     "debug",
            message:   "#{duration_ms.round}ms: #{sql.first(2000)}",
            timestamp: timestamp
          )
        end
      end
    end
  end
end
