require "spec_helper"
require "rack/test"

RSpec.describe NurseAndrea::MetricsMiddleware do
  include Rack::Test::Methods

  let(:inner_app) do
    lambda do |env|
      [200, { "Content-Type" => "text/plain" }, ["OK"]]
    end
  end

  let(:app) { NurseAndrea::MetricsMiddleware.new(inner_app) }

  before do
    NurseAndrea.configure do |c|
      c.api_key      = "test-token"
      c.host         = "http://localhost:4500"
      c.service_name = "test-service"
    end
  end

  it "passes the request through to the inner app" do
    get "/"
    expect(last_response.status).to eq(200)
    expect(last_response.body).to   eq("OK")
  end

  it "enqueues a metric on every request" do
    enqueued = []
    allow(NurseAndrea::MetricsShipper.instance)
      .to receive(:enqueue) { |metric| enqueued << metric }

    get "/"
    expect(enqueued.length).to eq(1)
  end

  it "tags the metric with the canonical http_method/http_path/http_status keys" do
    captured = nil
    allow(NurseAndrea::MetricsShipper.instance)
      .to receive(:enqueue) { |metric| captured = metric }

    get "/users/42"
    expect(captured[:name]).to eq("http.server.duration")
    expect(captured[:tags]).to include(
      http_method: "GET",
      http_status: "200",
      service:     "test-service",
    )
    expect(captured[:tags][:http_path]).to be_a(String)
  end

  it "records the response status as a string" do
    captured = nil
    allow(NurseAndrea::MetricsShipper.instance)
      .to receive(:enqueue) { |metric| captured = metric }

    inner = lambda { |_| [503, {}, ["fail"]] }
    NurseAndrea::MetricsMiddleware.new(inner).call(Rack::MockRequest.env_for("/x"))
    expect(captured[:tags][:http_status]).to eq("503")
  end

  it "is a no-op when the SDK is disabled (api_key blank)" do
    NurseAndrea.configure do |c|
      c.api_key = ""
      c.host    = "http://localhost:4500"
    end
    expect(NurseAndrea::MetricsShipper.instance).not_to receive(:enqueue)
    get "/"
  end

  it "skips its own /nurse_andrea/* endpoints" do
    expect(NurseAndrea::MetricsShipper.instance).not_to receive(:enqueue)
    get "/nurse_andrea/status"
  end
end
