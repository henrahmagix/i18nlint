# frozen_string_literal: true

require_relative "coverage_helper"

require "i18nlint"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.order = :random
  Kernel.srand config.seed

  config.run_all_when_everything_filtered = true

  config.before(:suite) do
    config.instance_variable_set(:@original_rule_types, I18nLint::Registry.rule_types.clone)
    config.instance_variable_set(:@original_rules, I18nLint::Registry.rules.clone)
  end
  config.before do
    I18nLint::Registry.instance_variable_set(:@rule_types, config.instance_variable_get(:@original_rule_types).clone)
    I18nLint::Registry.instance_variable_set(:@rules, config.instance_variable_get(:@original_rules).clone)
  end
end
