# frozen_string_literal: true

require "optparse"
require "yaml"

require_relative "../lint"

module I18n
  module Lint
    # Run the linter in your terminal.
    class CLI
      def self.run # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        source_locale = nil
        config = nil

        parser = OptionParser.new do |parser|
          parser.banner = "Usage: i18n-lint files... --source=LOCALE --config=path/to/.i18n-lint.yml"

          parser.on("--source=LOCALE", "The locale to configure segment comparisons against source.") do |v|
            source_locale = v
          end
          parser.on("--config=CONFIG", "The configuration of rules.") do |v|
            config = v
          end
        end
        parser.parse!

        if source_locale.nil?
          warn parser
          exit 1
        end

        config ||= [
          ::File.join(__dir__, ".i18n-lint.yml"),
          ::File.join(Dir.home, ".i18n-lint.yml")
        ].find { |f| ::File.exist?(f) }

        if config
          begin
            conf = ::YAML.safe_load_file(config)
            conf["Rules"]&.each do |rule|
              case rule
              when String
                if rule.match? %r{^/.*/$}
                  Registry.register_rule(::Regexp.new(rule[1..-2]))
                else
                  Registry.register_rule(::Regexp.new(::Regexp.escape(rule)))
                end
              else
                warn "TODO: implement config for other rule types"
              end
            end
          rescue ::Errno::ENOENT
            nil
          end
        end

        linter = Linter.new(filepaths: ARGV, source_locale:)
        warn "Inspecting #{linter.num_files} files"
        linter.tick_each_file { $stderr.print "." }
        linter.run

        if linter.offences.empty?
          warn "No offences detected"
          exit 0
        end

        warn "\nOffences:"
        linter.offences.each do |o|
          warn <<~MSG

            #{o.filepath}:#{o.lineno}: #{o.rule} in #{o.locale}.#{o.key}#{" - #{o.message}" if o.message}
              #{o.source}
          MSG
        end
        warn "\n#{linter.offences.size} offences detected"
        exit 1
      end
    end
  end
end
