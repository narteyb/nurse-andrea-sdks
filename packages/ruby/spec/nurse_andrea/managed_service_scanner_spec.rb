require "spec_helper"

RSpec.describe NurseAndrea::ManagedServiceScanner do
  around(:each) do |example|
    scan_vars = NurseAndrea::ManagedServiceScanner::SCAN_MAP.keys
    saved = scan_vars.each_with_object({}) { |k, h| h[k] = ENV[k] }
    scan_vars.each { |k| ENV.delete(k) }
    example.run
  ensure
    scan_vars.each { |k| ENV.delete(k) }
    saved.each { |k, v| v ? ENV[k] = v : ENV.delete(k) }
  end

  describe ".scan" do
    it "discovers DATABASE_URL as postgresql" do
      ENV["DATABASE_URL"] = "postgres://user:pass@db.railway.internal/app"
      results = described_class.scan
      expect(results.length).to eq(1)
      expect(results.first[:type]).to eq("database")
      expect(results.first[:tech]).to eq("postgresql")
      expect(results.first[:provider]).to eq("railway")
      expect(results.first[:source]).to eq("env_detection")
      expect(results.first[:variable_name]).to eq("DATABASE_URL")
    end

    it "discovers REDIS_URL as redis" do
      ENV["REDIS_URL"] = "redis://default:abc@us1-key.upstash.io:6379"
      results = described_class.scan
      expect(results.first[:type]).to eq("cache")
      expect(results.first[:tech]).to eq("redis")
    end

    it "discovers RABBITMQ_URL as rabbitmq" do
      ENV["RABBITMQ_URL"] = "amqp://user:pass@rabbit.fly.dev:5672"
      results = described_class.scan
      expect(results.first[:type]).to eq("queue")
      expect(results.first[:tech]).to eq("rabbitmq")
    end

    it "skips blank env vars" do
      ENV["DATABASE_URL"] = ""
      expect(described_class.scan).to be_empty
    end

    it "deduplicates DATABASE_URL and DATABASE_PRIVATE_URL" do
      ENV["DATABASE_URL"] = "postgres://user:pass@db.railway.internal/app"
      ENV["DATABASE_PRIVATE_URL"] = "postgres://user:pass@db.railway.internal/app"
      expect(described_class.scan.length).to eq(1)
    end

    it "result contains no raw URLs" do
      ENV["DATABASE_URL"] = "postgres://user:secret_pass@db.neon.tech/mydb"
      results = described_class.scan
      flat = results.map(&:values).flatten.join(" ")
      expect(flat).not_to include("secret_pass")
      expect(flat).not_to include("postgres://")
      expect(flat).not_to include("mydb")
    end

    it "result passes through Sanitizer allowlist" do
      ENV["DATABASE_URL"] = "postgres://user:pass@localhost/db"
      results = described_class.scan
      results.each do |r|
        expect(r.keys - NurseAndrea::Sanitizer::DISCOVERY_ALLOWLIST).to be_empty
      end
    end
  end

  describe ".scan with SelfFilter" do
    before { NurseAndrea::SelfFilter.reset! }
    after  { NurseAndrea::SelfFilter.reset! }

    it "returns [] entirely when running inside NurseAndrea" do
      allow(NurseAndrea::SelfFilter).to receive(:platform_self?).and_return(true)
      ENV["DATABASE_URL"] = "postgres://user:pass@db.railway.internal/app"
      ENV["REDIS_URL"]    = "redis://default:abc@cache.aws.com:6379"
      expect(described_class.scan).to eq([])
    end

    it "drops a URL whose host contains a self-indicator" do
      allow(NurseAndrea::SelfFilter).to receive(:platform_self?).and_return(false)
      ENV["DATABASE_URL"] = "postgres://user:pass@db.nurseandrea.io/app"
      expect(described_class.scan).to eq([])
    end

    it "keeps a URL whose host is unrelated to NurseAndrea" do
      allow(NurseAndrea::SelfFilter).to receive(:platform_self?).and_return(false)
      ENV["DATABASE_URL"] = "postgres://user:pass@shop-db.aws.com/shop"
      expect(described_class.scan.length).to eq(1)
    end
  end
end
