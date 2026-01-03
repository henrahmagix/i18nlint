# frozen_string_literal: true

require_relative "coverage_helper"

require "i18nlint"
require "i18nlint/rspec/expect_offence"

require_relative "support/reset_global_state"
require_relative "support/example_files"

ORIG_STDOUT = $stdout # use this when debugging in tests that capture stdout/stderr
ORIG_STDERR = $stderr

RSpec.configure do |config|
  config.include I18nLint::RSpec::ExpectOffence

  config.before(:suite) { ResetGlobalState.setup }
  config.before(:each) { ResetGlobalState.reset }

  config.include ExampleFiles
  config.before(:suite) { ExampleFiles.setup }
  config.before(:each) { ExampleFiles.reset }

  config.disable_monkey_patching!

  config.expect_with(:rspec) do |c|
    c.syntax = :expect
    c.max_formatted_output_length = 500 # our structs are long
  end

  config.order = :random
  Kernel.srand config.seed

  config.run_all_when_everything_filtered = true
end
