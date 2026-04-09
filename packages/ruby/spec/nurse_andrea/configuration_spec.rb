require "spec_helper"

RSpec.describe NurseAndrea::Configuration do
  describe "defaults" do
    subject(:config) { described_class.new }

    it "defaults host to the production endpoint" do
      expect(config.host).to eq(NurseAndrea::Configuration::DEFAULT_HOST)
    end

    it "is enabled by default" do
      expect(config.enabled?).to be true
    end

    it "defaults flush_interval and batch_size to sensible numbers" do
      expect(config.flush_interval).to be > 0
      expect(config.batch_size).to be > 0
    end

    it "stamps sdk_language as ruby" do
      expect(config.sdk_language).to eq("ruby")
    end

    it "stamps sdk_version from NurseAndrea::VERSION" do
      expect(config.sdk_version).to eq(NurseAndrea::VERSION)
    end
  end

  describe "token alias" do
    it "exposes token= as an alias for api_key=" do
      NurseAndrea.configure { |c| c.token = "alias-token" }
      expect(NurseAndrea.config.api_key).to eq("alias-token")
      expect(NurseAndrea.config.token).to   eq("alias-token")
    end
  end

  describe "#valid?" do
    it "is invalid when api_key is nil" do
      NurseAndrea.configure do |c|
        c.api_key = nil
        c.host    = "http://localhost:4500"
      end
      expect(NurseAndrea.config.valid?).to be false
    end

    it "is invalid when api_key is blank" do
      NurseAndrea.configure do |c|
        c.api_key = "   "
        c.host    = "http://localhost:4500"
      end
      expect(NurseAndrea.config.valid?).to be false
    end

    it "is invalid when host is nil" do
      NurseAndrea.configure do |c|
        c.api_key = "tok"
        c.host    = nil
      end
      expect(NurseAndrea.config.valid?).to be false
    end

    it "is valid when both api_key and host are present" do
      NurseAndrea.configure do |c|
        c.api_key = "tok"
        c.host    = "http://localhost:4500"
      end
      expect(NurseAndrea.config.valid?).to be true
    end
  end

  describe "#validate!" do
    it "raises ConfigurationError when invalid" do
      NurseAndrea.configure { |c| c.api_key = nil }
      expect { NurseAndrea.config.validate! }
        .to raise_error(NurseAndrea::ConfigurationError, /Configuration invalid/)
    end

    it "returns self when valid" do
      NurseAndrea.configure do |c|
        c.api_key = "tok"
        c.host    = "http://localhost:4500"
      end
      expect(NurseAndrea.config.validate!).to be(NurseAndrea.config)
    end
  end

  describe "derived URLs" do
    before do
      NurseAndrea.configure do |c|
        c.api_key = "tok"
        c.host    = "http://localhost:4500"
      end
    end

    it "derives ingest_url from host" do
      expect(NurseAndrea.config.ingest_url).to eq("http://localhost:4500/api/v1/ingest")
    end

    it "derives metrics_url from host" do
      expect(NurseAndrea.config.metrics_url).to eq("http://localhost:4500/api/v1/metrics")
    end

    it "strips trailing slash from host before deriving URLs" do
      NurseAndrea.configure do |c|
        c.api_key = "tok"
        c.host    = "http://localhost:4500/"
      end
      expect(NurseAndrea.config.ingest_url).to eq("http://localhost:4500/api/v1/ingest")
    end
  end
end
