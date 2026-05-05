require "spec_helper"

RSpec.describe NurseAndrea::Sanitizer do
  describe ".sanitize_discovery" do
    it "strips non-allowlisted fields" do
      raw = { type: "database", tech: "postgresql", provider: "railway",
              source: "env_detection", variable_name: "DATABASE_URL",
              raw_url: "postgres://user:pass@host/db", secret: "abc123" }
      result = described_class.sanitize_discovery(raw)
      expect(result.keys).to match_array(%i[type tech provider source variable_name])
      expect(result).not_to have_key(:raw_url)
      expect(result).not_to have_key(:secret)
    end

    it "passes all allowlisted fields through" do
      raw = { type: "cache", tech: "redis", provider: "upstash",
              source: "env_detection", variable_name: "REDIS_URL" }
      result = described_class.sanitize_discovery(raw)
      expect(result).to eq(raw)
    end
  end

  describe ".extract_tech" do
    it "parses postgres:// as postgresql" do
      expect(described_class.extract_tech("postgres://user:pass@host/db")).to eq("postgresql")
    end

    it "parses postgresql:// as postgresql" do
      expect(described_class.extract_tech("postgresql://user:pass@host/db")).to eq("postgresql")
    end

    it "parses redis:// as redis" do
      expect(described_class.extract_tech("redis://host:6379")).to eq("redis")
    end

    it "parses amqp:// as rabbitmq" do
      expect(described_class.extract_tech("amqp://host:5672")).to eq("rabbitmq")
    end

    it "parses mongodb:// as mongodb" do
      expect(described_class.extract_tech("mongodb://host:27017/db")).to eq("mongodb")
    end

    it "returns unknown for invalid URL" do
      expect(described_class.extract_tech("not-a-url")).to eq("unknown")
    end
  end

  describe ".extract_provider" do
    it "matches *.railway.internal as railway" do
      expect(described_class.extract_provider("postgres://user:pass@db.railway.internal/app")).to eq("railway")
    end

    it "matches *.neon.tech as neon" do
      expect(described_class.extract_provider("postgres://user:pass@ep-cool-name.neon.tech/db")).to eq("neon")
    end

    it "matches *.upstash.io as upstash" do
      expect(described_class.extract_provider("redis://default:abc@us1-key.upstash.io:6379")).to eq("upstash")
    end

    it "returns self_hosted for unknown host" do
      expect(described_class.extract_provider("postgres://user:pass@localhost/db")).to eq("self_hosted")
    end

    it "returns unknown for invalid URL" do
      expect(described_class.extract_provider("not-a-url")).to eq("unknown")
    end
  end
end
