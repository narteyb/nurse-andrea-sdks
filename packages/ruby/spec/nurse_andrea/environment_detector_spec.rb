require "spec_helper"

RSpec.describe NurseAndrea::EnvironmentDetector do
  before do
    described_class.reset_warning!
    @prev_rails_env = ENV.delete("RAILS_ENV")
    @prev_rack_env  = ENV.delete("RACK_ENV")
  end

  after do
    ENV["RAILS_ENV"] = @prev_rails_env if @prev_rails_env
    ENV["RACK_ENV"]  = @prev_rack_env  if @prev_rack_env
  end

  describe ".detect" do
    it "returns 'production' when no env var is set" do
      expect(described_class.detect).to eq("production")
    end

    it "returns the value when RAILS_ENV is one of the supported set" do
      ENV["RAILS_ENV"] = "staging"
      expect(described_class.detect).to eq("staging")
    end

    it "falls back to RACK_ENV when RAILS_ENV is unset" do
      ENV["RACK_ENV"] = "development"
      expect(described_class.detect).to eq("development")
    end

    it "falls back to 'production' for unsupported values like 'test'" do
      ENV["RAILS_ENV"] = "test"
      expect(described_class.detect).to eq("production")
    end

    it "warns once for an unsupported value, not on subsequent calls" do
      ENV["RAILS_ENV"] = "qa"
      output = capture_stderr { 3.times { described_class.detect } }
      occurrences = output.scan("[NurseAndrea]").size
      expect(occurrences).to eq(1)
    end
  end

  def capture_stderr
    original = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = original
  end
end
