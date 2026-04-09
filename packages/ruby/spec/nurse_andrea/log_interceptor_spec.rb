require "spec_helper"
require "logger"
require "stringio"

RSpec.describe NurseAndrea::LogInterceptor do
  let(:io)             { StringIO.new }
  let(:original_logger) { Logger.new(io).tap { |l| l.level = Logger::DEBUG } }
  let(:interceptor)    { described_class.new(original_logger) }

  before do
    NurseAndrea.configure do |c|
      c.api_key      = "test-token"
      c.host         = "http://localhost:4500"
      c.service_name = "test-service"
      c.log_level    = :debug
    end
  end

  it "delegates writes to the wrapped logger" do
    interceptor.error("Something went wrong")
    expect(io.string).to include("Something went wrong")
  end

  it "enqueues an error log entry to LogShipper" do
    captured = []
    allow(NurseAndrea::LogShipper.instance)
      .to receive(:enqueue) { |entry| captured << entry }

    interceptor.error("DB connection failed")

    expect(captured.length).to eq(1)
    expect(captured.first).to include(level: "error", message: "DB connection failed")
  end

  it "enqueues a warn log entry" do
    captured = nil
    allow(NurseAndrea::LogShipper.instance)
      .to receive(:enqueue) { |entry| captured = entry }

    interceptor.warn("Watch out")
    expect(captured[:level]).to eq("warn")
  end

  it "enqueues an info log entry" do
    captured = nil
    allow(NurseAndrea::LogShipper.instance)
      .to receive(:enqueue) { |entry| captured = entry }

    interceptor.info("Just FYI")
    expect(captured[:level]).to eq("info")
  end

  it "stamps a timestamp on each enqueued entry" do
    captured = nil
    allow(NurseAndrea::LogShipper.instance)
      .to receive(:enqueue) { |entry| captured = entry }

    interceptor.error("X")
    expect(captured[:timestamp]).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z\z/)
  end

  it "is a no-op when the SDK is disabled" do
    NurseAndrea.configure do |c|
      c.api_key = nil
      c.host    = "http://localhost:4500"
    end
    expect(NurseAndrea::LogShipper.instance).not_to receive(:enqueue)
    interceptor.error("Will not ship")
  end

  it "respects the configured min log level (info filters out debug)" do
    NurseAndrea.configure do |c|
      c.api_key   = "test-token"
      c.host      = "http://localhost:4500"
      c.log_level = :info
    end
    fresh = described_class.new(Logger.new(StringIO.new).tap { |l| l.level = Logger::DEBUG })

    expect(NurseAndrea::LogShipper.instance).not_to receive(:enqueue)
    fresh.debug("below threshold")
  end
end
