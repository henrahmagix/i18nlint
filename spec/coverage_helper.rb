# frozen_string_literal: true

require "simplecov"
require "simplecov-lcov"

SimpleCov.configure do
  coverage_dir "coverage"
  enable_coverage :branch
  track_files "lib/**/*.rb"
end

SimpleCov::Formatter::LcovFormatter.config.report_with_single_file = true
SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new(
  [
    Class.new(SimpleCov::Formatter::HTMLFormatter) do
      def output_message(result)
        # Override default output to remove coverage stats.
        "HTML coverage report generated for #{result.command_name} to #{File.join(output_path, "index.html")}"
      end
    end,
    SimpleCov::Formatter::LcovFormatter
  ]
)

SimpleCov.at_exit do
  line_cov, branch_cov = SimpleCov.result.coverage_statistics.values_at(:line, :branch)
  puts "Covered #{line_cov.covered}/#{line_cov.total} lines (#{line_cov.percent.round(2)}%) and " \
       "#{branch_cov.covered}/#{branch_cov.total} branches (#{branch_cov.percent.round(2)}%)"
  puts
  SimpleCov.result.format!
end

SimpleCov.start
