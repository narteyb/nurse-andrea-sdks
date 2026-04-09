require "spec_helper"
require "active_job"

# Test job classes — defined at the top level so ActiveJob can resolve them.
class TestJob < ActiveJob::Base
  include NurseAndrea::JobInstrumentation
  queue_as :default

  def perform
    # no-op
  end
end

class FailingTestJob < ActiveJob::Base
  include NurseAndrea::JobInstrumentation
  queue_as :critical

  def perform
    raise RuntimeError, "Job always fails"
  end
end

RSpec.describe NurseAndrea::JobInstrumentation do
  before do
    NurseAndrea.configure do |c|
      c.api_key      = "test-token"
      c.host         = "http://localhost:4500"
      c.service_name = "test-service"
    end
    ActiveJob::Base.queue_adapter = :test
  end

  it "enqueues exactly one metric per successful job" do
    captured = []
    allow(NurseAndrea::MetricsShipper.instance)
      .to receive(:enqueue) { |m| captured << m }

    TestJob.perform_now
    expect(captured.length).to eq(1)
  end

  it "names the metric job.perform" do
    captured = nil
    allow(NurseAndrea::MetricsShipper.instance)
      .to receive(:enqueue) { |m| captured = m }
    TestJob.perform_now
    expect(captured[:name]).to eq("job.perform")
  end

  it "tags successful jobs with status: completed" do
    captured = nil
    allow(NurseAndrea::MetricsShipper.instance)
      .to receive(:enqueue) { |m| captured = m }
    TestJob.perform_now
    expect(captured[:tags]).to include(
      job_class:  "TestJob",
      queue_name: "default",
      status:     "completed",
    )
  end

  it "tags failing jobs with status: failed and error_class" do
    captured = nil
    allow(NurseAndrea::MetricsShipper.instance)
      .to receive(:enqueue) { |m| captured = m }

    expect { FailingTestJob.perform_now }.to raise_error(RuntimeError)

    expect(captured[:tags]).to include(
      job_class:   "FailingTestJob",
      status:      "failed",
      error_class: "RuntimeError",
    )
  end

  it "records a numeric duration value in milliseconds" do
    captured = nil
    allow(NurseAndrea::MetricsShipper.instance)
      .to receive(:enqueue) { |m| captured = m }
    TestJob.perform_now
    # A no-op job rounds to 0.0ms; just assert the schema, not the magnitude.
    expect(captured[:value]).to be_a(Numeric)
    expect(captured[:value]).to be >= 0
    expect(captured[:unit]).to  eq("ms")
  end

  it "is a no-op when the SDK is disabled (config.enabled = false)" do
    NurseAndrea.configure do |c|
      c.api_key = "test-token"
      c.host    = "http://localhost:4500"
      c.enabled = false
    end
    expect(NurseAndrea::MetricsShipper.instance).not_to receive(:enqueue)
    TestJob.perform_now
  end
end
