require "spec_helper"
require "bundler"
require "json"
require "tempfile"

# Sprint D D1 (GAP-09) — Rack-compatible core spec.
#
# The other RSpec files run under the gem's Bundler env, which has
# Rails and ActiveSupport in $LOAD_PATH (they're development
# dependencies for the host-app fixture). That env can't prove
# anything about behavior in a Sinatra / plain-Rack process where
# Rails is genuinely absent.
#
# This spec spawns a fresh `ruby` subprocess with the Bundler env
# stripped and only the gem's `lib/` on the load path, then asserts
# the public API loads and works without Rails. The subprocess
# returns its findings as JSON to stdout; this spec parses and
# asserts on them.
RSpec.describe "Rack-compatible core (Sprint D D1)" do
  let(:lib_dir) { File.expand_path("../../lib", __dir__) }

  # Probe script. Runs in the subprocess. Captures every assertion
  # as a key/value pair so we can fail per-assertion in the parent
  # spec instead of having one all-or-nothing exit code.
  let(:probe_script) do
    <<~RUBY
      require "json"

      result = {}

      # 1. The gem loads at all.
      begin
        require "nurse_andrea"
        result[:load_ok] = true
      rescue LoadError => e
        result[:load_ok] = false
        result[:load_error] = e.message
      end

      if result[:load_ok]
        # 2. configure + valid? work.
        begin
          NurseAndrea.configure do |c|
            c.org_token      = "org_test_aaaaaaaaaaaaaaaaaaaaaa"
            c.workspace_slug = "rack-app"
            c.environment    = "development"
            c.host           = "https://example.test"
          end
          result[:configure_ok] = true
          result[:valid] = NurseAndrea.config.valid?
        rescue => e
          result[:configure_ok] = false
          result[:configure_error] = "\#{e.class}: \#{e.message}"
        end

        # 3. Shippers exist and can be referenced (singletons).
        result[:log_shipper_defined]     = defined?(NurseAndrea::LogShipper) ? true : false
        result[:metrics_shipper_defined] = defined?(NurseAndrea::MetricsShipper) ? true : false
        result[:log_shipper_instance]    = (NurseAndrea::LogShipper.instance.class.name == "NurseAndrea::LogShipper")
        result[:metrics_shipper_instance] = (NurseAndrea::MetricsShipper.instance.class.name == "NurseAndrea::MetricsShipper")

        # 4. Rails-only layer NOT loaded.
        result[:engine_defined]  = defined?(NurseAndrea::Engine)  ? true : false
        result[:railtie_defined] = defined?(NurseAndrea::Railtie) ? true : false
        result[:job_instr_defined] = defined?(NurseAndrea::JobInstrumentation) ? true : false

        # 5. Rails / ActiveSupport not pulled in transitively.
        result[:rails_defined] = defined?(Rails) ? true : false
        result[:active_support_defined] = defined?(ActiveSupport) ? true : false
      end

      print JSON.generate(result)
    RUBY
  end

  let(:subprocess_output) do
    Tempfile.create(["probe", ".rb"]) do |f|
      f.write(probe_script)
      f.flush

      # Strip Bundler env so the subprocess doesn't inherit the gem's
      # development dependencies. Force a minimal load path: only the
      # gem's own lib/ dir. Anything in RUBYOPT (-rbundler/setup) is
      # also cleared via with_unbundled_env.
      output = nil
      Bundler.with_unbundled_env do
        ENV["RUBYOPT"] = nil
        output = `ruby -I "#{lib_dir}" "#{f.path}" 2>&1`
      end
      output
    end
  end

  let(:result) do
    # Subprocess may emit warnings before the JSON line; find the
    # JSON payload at the tail.
    json_line = subprocess_output.lines.reverse.find { |l| l.strip.start_with?("{") }
    raise "no JSON in subprocess output:\n#{subprocess_output}" unless json_line
    JSON.parse(json_line.strip, symbolize_names: true)
  end

  it "loads without raising LoadError" do
    expect(result[:load_ok]).to eq(true),
      "expected gem to load in non-Rails Ruby. error: #{result[:load_error].inspect}"
  end

  it "accepts NurseAndrea.configure { ... } and reports valid? true" do
    expect(result[:configure_ok]).to eq(true),
      "configure raised: #{result[:configure_error].inspect}"
    expect(result[:valid]).to eq(true)
  end

  it "defines and can instantiate LogShipper" do
    expect(result[:log_shipper_defined]).to eq(true)
    expect(result[:log_shipper_instance]).to eq(true)
  end

  it "defines and can instantiate MetricsShipper" do
    expect(result[:metrics_shipper_defined]).to eq(true)
    expect(result[:metrics_shipper_instance]).to eq(true)
  end

  it "does NOT define NurseAndrea::Engine in a non-Rails context" do
    expect(result[:engine_defined]).to eq(false)
  end

  it "does NOT define NurseAndrea::Railtie in a non-Rails context" do
    expect(result[:railtie_defined]).to eq(false)
  end

  it "does NOT pull in JobInstrumentation (ActiveSupport::Concern) without Rails" do
    expect(result[:job_instr_defined]).to eq(false)
  end

  it "does NOT transitively pull in Rails" do
    expect(result[:rails_defined]).to eq(false)
  end

  it "does NOT transitively pull in ActiveSupport" do
    expect(result[:active_support_defined]).to eq(false)
  end
end
