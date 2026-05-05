# PRIVACY: This file subscribes to framework instrumentation hooks.
# Query text is aggregated (table names extracted) but never shipped raw.
# See DATA_PRIVACY_POLICY.rb for the full policy.

require "set"

module NurseAndrea
  class InstrumentationSubscriber
    SUBSCRIPTIONS = {
      "sql.active_record"           => :on_sql,
      "transaction.active_record"   => :on_transaction,
      "cache_read.active_support"   => :on_cache_read,
      "cache_write.active_support"  => :on_cache_write,
      "cache_delete.active_support" => :on_cache_delete,
      "perform.active_job"          => :on_job_perform,
      "enqueue.active_job"          => :on_job_enqueue,
      "deliver.action_mailer"       => :on_mailer
    }.freeze

    attr_reader :telemetry, :discovered_components

    def initialize
      @telemetry = ComponentTelemetry.new
      @discovered_components = Set.new
      @subscribed = false
    end

    def subscribe_all
      return if @subscribed
      return unless defined?(ActiveSupport::Notifications)

      SUBSCRIPTIONS.each do |event_name, handler|
        ActiveSupport::Notifications.monotonic_subscribe(event_name) do |event|
          begin
            send(handler, event)
          rescue => e
            NurseAndrea.debug("[InstrumentationSubscriber] #{handler} error: #{e.message}")
          end
        end
      end

      @subscribed = true
    end

    private

    def on_sql(event)
      return if event.payload[:name] == "SCHEMA"
      return if event.payload[:name]&.start_with?("EXPLAIN")

      conn    = event.payload[:connection]
      adapter = conn&.adapter_name rescue nil

      # Skip platform's own ClickHouse queries — not the customer's infrastructure
      return if adapter&.downcase&.include?("clickhouse")

      tech = adapter_to_tech(adapter)
      register_discovery("database", tech, connection: conn) if tech

      table = extract_table(event.payload[:sql])
      @telemetry.record_query(duration_ms: event.duration, table: table)
    end

    def on_transaction(event)
      outcome = event.payload[:outcome]
      @telemetry.record_transaction(outcome: outcome)
    end

    def on_cache_read(event)
      tech = store_to_tech(event.payload[:store])

      # Only register external cache stores as components
      register_discovery("cache", tech) if tech

      # Still record telemetry for all cache reads
      @telemetry.record_cache_read(hit: event.payload[:hit])
    end

    def on_cache_write(_event)
      @telemetry.record_cache_write
    end

    def on_cache_delete(_event)
      @telemetry.record_cache_delete
    end

    def on_job_perform(event)
      adapter = detect_queue_adapter
      register_discovery("queue", adapter)
      @telemetry.record_job_complete(
        duration_ms: event.duration,
        queue_name: event.payload[:job]&.queue_name
      )
    end

    def on_job_enqueue(event)
      @telemetry.record_job_enqueue(queue_name: event.payload[:job]&.queue_name)
    end

    def on_mailer(_event)
      register_discovery("external", "email")
    end

    def register_discovery(type, tech, connection: nil)
      return if tech.nil? || tech.empty? || tech == "unknown"
      return if self_referential?(connection)

      key = "#{type}:#{tech}"
      return if @discovered_components.include?(key)

      @discovered_components.add(key)
      NurseAndrea.component_discoveries << Sanitizer.sanitize_discovery(
        type: type, tech: tech, provider: "unknown",
        source: "hook_subscription", variable_name: nil
      )
    end

    # True when the SDK is running inside NurseAndrea itself, OR when
    # the SQL event's connection points at NurseAndrea's own infra.
    # Either way the discovery would be a self-reference, not a
    # customer component. Process-level + connection-level checks are
    # both consulted; the same module powers the env-scanner filter.
    def self_referential?(connection)
      return true if NurseAndrea::SelfFilter.platform_self?
      return false unless connection

      db_name = connection.current_database.to_s rescue ""
      host    = connection.pool&.db_config&.host.to_s rescue ""
      NurseAndrea::SelfFilter.host_matches?(db_name, host)
    end

    def adapter_to_tech(adapter_name)
      case adapter_name&.downcase
      when "postgresql", "postgis" then "postgresql"
      when "mysql2", "trilogy"     then "mysql"
      when "sqlite3"               then "sqlite"
      when "clickhouse"            then nil
      else adapter_name&.downcase.presence
      end
    end

    def store_to_tech(store_class)
      case store_class.to_s
      when /Redis/i    then "redis"
      when /Memcache/i then "memcached"
      when /Memory/i   then nil  # In-process, not infrastructure
      when /File/i     then nil  # Local filesystem, not infrastructure
      when /Null/i     then nil  # No-op store
      else nil
      end
    end

    def detect_queue_adapter
      return "unknown" unless defined?(ActiveJob::Base)
      adapter = ActiveJob::Base.queue_adapter.class.name rescue nil
      case adapter
      when /Sidekiq/i    then "sidekiq"
      when /SolidQueue/i then "solid_queue"
      when /Resque/i     then "resque"
      when /DelayedJob/i then "delayed_job"
      when /GoodJob/i    then "good_job"
      else "unknown"
      end
    end

    def extract_table(sql)
      return nil if sql.nil? || sql.empty?
      if sql =~ /\bFROM\s+["`]?(\w+)["`]?/i
        $1
      elsif sql =~ /\bINTO\s+["`]?(\w+)["`]?/i
        $1
      elsif sql =~ /\bUPDATE\s+["`]?(\w+)["`]?/i
        $1
      end
    end
  end
end
