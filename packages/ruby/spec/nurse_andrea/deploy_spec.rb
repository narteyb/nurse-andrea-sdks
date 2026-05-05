require "spec_helper"

RSpec.describe NurseAndrea::Deploy do
  let(:http) { instance_double(NurseAndrea::HttpClient, post: true) }

  before do
    NurseAndrea.configure do |c|
      c.api_key = "test-token"
      c.host    = "http://localhost:4500"
    end
    allow(NurseAndrea::HttpClient).to receive(:new).and_return(http)
  end

  describe ".call" do
    it "ships to /api/v1/deploy with version" do
      expect(http).to receive(:post).with(
        "http://localhost:4500/api/v1/deploy",
        hash_including(version: "1.4.2")
      )
      described_class.call(version: "1.4.2")
    end

    it "includes deployer when provided" do
      expect(http).to receive(:post).with(
        anything, hash_including(deployer: "dan")
      )
      described_class.call(version: "1.0.0", deployer: "dan")
    end

    it "defaults environment to production" do
      expect(http).to receive(:post).with(
        anything, hash_including(environment: "production")
      )
      described_class.call(version: "1.0.0")
    end

    it "honors explicit environment" do
      expect(http).to receive(:post).with(
        anything, hash_including(environment: "staging")
      )
      described_class.call(version: "1.0.0", environment: "staging")
    end

    it "stamps deployed_at as iso8601 UTC" do
      captured = nil
      allow(http).to receive(:post) { |_, body| captured = body; true }
      described_class.call(version: "1.0.0")
      expect(captured[:deployed_at]).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/)
    end

    it "truncates description to 500 chars" do
      captured = nil
      allow(http).to receive(:post) { |_, body| captured = body; true }
      described_class.call(version: "1.0.0", description: "a" * 600)
      expect(captured[:description].length).to eq(500)
    end

    it "returns false when version is blank" do
      expect(http).not_to receive(:post)
      expect(described_class.call(version: "")).to be(false)
    end

    it "returns false when configuration is invalid" do
      NurseAndrea.reset_config!
      expect(http).not_to receive(:post)
      expect(described_class.call(version: "1.0.0")).to be(false)
    end

    it "swallows network errors" do
      allow(http).to receive(:post).and_raise(Errno::ECONNREFUSED)
      expect { described_class.call(version: "1.0.0") }.not_to raise_error
    end
  end

  describe "NurseAndrea.deploy convenience" do
    it "delegates to Deploy.call" do
      expect(NurseAndrea::Deploy).to receive(:call).with(version: "2.0.0")
      NurseAndrea.deploy(version: "2.0.0")
    end
  end
end
