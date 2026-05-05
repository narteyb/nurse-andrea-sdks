require "spec_helper"

RSpec.describe NurseAndrea::PlatformDetector do
  around(:each) do |example|
    original = ENV.to_h.slice(*%w[RAILWAY_ENVIRONMENT RAILWAY_REGION RENDER RENDER_REGION
                                   FLY_APP_NAME FLY_REGION DYNO
                                   DIGITALOCEAN_APP_PLATFORM_COMPONENT_NAME VERCEL])
    example.run
  ensure
    # Restore
    %w[RAILWAY_ENVIRONMENT RAILWAY_REGION RENDER RENDER_REGION
       FLY_APP_NAME FLY_REGION DYNO
       DIGITALOCEAN_APP_PLATFORM_COMPONENT_NAME VERCEL].each { |k| ENV.delete(k) }
    original.each { |k, v| ENV[k] = v }
  end

  describe ".detect" do
    it "detects Railway from RAILWAY_ENVIRONMENT" do
      ENV["RAILWAY_ENVIRONMENT"] = "production"
      expect(described_class.detect).to eq("railway")
    end

    it "detects Render from RENDER" do
      ENV["RENDER"] = "true"
      expect(described_class.detect).to eq("render")
    end

    it "detects Fly from FLY_APP_NAME" do
      ENV["FLY_APP_NAME"] = "my-app"
      expect(described_class.detect).to eq("fly")
    end

    it "detects Heroku from DYNO" do
      ENV["DYNO"] = "web.1"
      expect(described_class.detect).to eq("heroku")
    end

    it "returns unknown when no platform vars set" do
      expect(described_class.detect).to eq("unknown")
    end
  end

  describe ".context" do
    it "includes region for Railway" do
      ENV["RAILWAY_ENVIRONMENT"] = "production"
      ENV["RAILWAY_REGION"] = "us-west1"
      ctx = described_class.context
      expect(ctx[:platform]).to eq("railway")
      expect(ctx[:region]).to eq("us-west1")
      expect(ctx[:environment]).to eq("production")
    end

    it "includes platform for unknown" do
      ctx = described_class.context
      expect(ctx[:platform]).to eq("unknown")
    end
  end
end
