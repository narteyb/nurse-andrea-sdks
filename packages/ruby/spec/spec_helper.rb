require "nurse_andrea"

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Reset the singleton config + thread-backed shippers between examples
  # so test order doesn't matter and one test's enqueued metric doesn't
  # bleed into the next test's expectations.
  config.before(:each) do
    NurseAndrea.reset_config!
    if defined?(NurseAndrea::MetricsShipper)
      NurseAndrea::MetricsShipper.instance.instance_variable_set(:@queue, [])
    end
    if defined?(NurseAndrea::LogShipper)
      NurseAndrea::LogShipper.instance.instance_variable_set(:@queue, [])
    end
  end
end
