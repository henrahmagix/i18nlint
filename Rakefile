# frozen_string_literal: true

require "English"
require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec).tap do |rspec_task|
  rspec_task.verbose = false
  rspec_task.fail_on_error = true
  rspec_task.rspec_opts = %w[--tag focus]
  rspec_task.rspec_opts += ["--seed", ENV["SEED"]] if ENV["SEED"]
end

require "rubocop/rake_task"

RuboCop::RakeTask.new

task :exe do
  system "exe/i18n-lint", "--source=en", "--config=spec/examples/cli/config.yml", "spec/examples/cli/locales/*.yml"
  puts "Result: exit #{$CHILD_STATUS.exitstatus}. Allowing Rake to continue: failing examples are helpful to see."
end

task default: %i[spec exe rubocop]
