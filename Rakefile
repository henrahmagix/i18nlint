# frozen_string_literal: true

require "English"
require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec).tap do |rspec_task|
  rspec_task.verbose = false
  rspec_task.fail_on_error = true
  rspec_task.rspec_opts += ["--seed", ENV["SEED"]] if ENV["SEED"]
end

require "rubocop/rake_task"

RuboCop::RakeTask.new

task :exe do
  puts "Testing exe/i18nlint..."
  system "exe/i18nlint", "--source=en", "--config=spec/examples/cli/config.yml", "spec/examples/cli/locales/*.yml"
  unless $CHILD_STATUS.exitstatus.zero?
    puts "Result: exit #{$CHILD_STATUS.exitstatus}. Allowing Rake to continue: failing examples are helpful to see."
  end
end

require_relative "spec/support/system_in_dummy_app"
task :railtie do
  puts "Testing railtie..."
  SystemInDummyApp.system("bin/rails i18nlint")
  unless $CHILD_STATUS.exitstatus.zero?
    puts "Result: exit #{$CHILD_STATUS.exitstatus}. Allowing Rake to continue: failing examples are helpful to see."
  end
end

task default: %i[spec exe railtie rubocop]
