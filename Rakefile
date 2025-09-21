# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec).tap do |rspec_task|
  rspec_task.verbose = false
  rspec_task.fail_on_error = true
  rspec_task.rspec_opts = %w[--tag focus]
end

require "rubocop/rake_task"

RuboCop::RakeTask.new

task :exe do
  system "exe/i18n-lint", "--source=en", "--config=spec/examples/exe/config.yml", "spec/examples/exe/locales/*.yml"
end

task default: %i[spec exe rubocop]
