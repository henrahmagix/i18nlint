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
  puts "Testing exe/i18nlint..."
  system "exe/i18nlint", "--source=en", "--config=spec/examples/cli/config.yml", "spec/examples/cli/locales/*.yml"
  unless $CHILD_STATUS.exitstatus.zero?
    puts "Result: exit #{$CHILD_STATUS.exitstatus}. Allowing Rake to continue: failing examples are helpful to see."
  end
end

task :railtie do
  puts "Testing railtie..."
  # We must unset bundler env so the system call can set its own bundle env as per the dummy app folder.
  env_without_bundler = ENV.reject { |k, _v| k.start_with?("BUNDLE") }
  system(env_without_bundler, "bin/rails i18nlint", unsetenv_others: true, chdir: "spec/dummy")
  unless $CHILD_STATUS.exitstatus.zero?
    puts "Result: exit #{$CHILD_STATUS.exitstatus}. Allowing Rake to continue: failing examples are helpful to see."
  end
end

task default: %i[spec exe railtie rubocop]
