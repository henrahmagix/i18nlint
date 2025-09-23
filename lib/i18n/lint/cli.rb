# frozen_string_literal: true

require "optparse"
require "yaml"

require "i18n/lint"

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
          conf = begin
            ::YAML.safe_load_file(config)
          rescue ::Errno::ENOENT
            {}
          end

          conf.delete("require").each do |path|
            require ::File.expand_path(path, ::File.dirname(config))
          end

          Rule.subclasses.each do |rule_class|
            rule_conf = { "Enabled" => rule_class.enabled_by_default? }

            anonymous = rule_class.rule_key.empty?
            rule_conf.merge!(conf.delete(rule_class.rule_key) || {}) if rule_class.rule_key

            next unless rule_conf["Enabled"]

            if anonymous
              warn "Anonymous subclasses of I18n::Lint::Rule cannot have configuration unless ::name is defined: " \
                   "#{rule_class.inspect}"
            end
            Registry.register_rule(rule_class, rule_conf)
          rescue RuleTypes::ClassRule::WillNeverRun => e
            raise unless anonymous

            warn "Anonymous subclass of I18n::Lint::Rule cannot be registered: #{e}"
          end

          conf.each_key do |key|
            warn "Unused configuration: #{key.inspect}. If this is a rule you're expecting to be used, this means it " \
                 "hasn't been required or isn't named #{key.gsub("/", "::")} or " \
                 "I18n::Lint::Rule::#{key.gsub("/", "::")}"
          end
          warn "\n"
        end

        linter = Linter.new(filepaths: ARGV, source_locale:)
        puts "Inspecting #{linter.num_files} files"
        linter.tick_each_file { print "." }
        linter.run

        if linter.offences.empty?
          puts "\n\nNo offences detected\n\n"
          exit 0
        end

        puts "\n\nOffences:"
        linter.offences.each do |o|
          file_info = "#{o.filepath}#{":#{o.lineno}" if o.lineno}"
          segment_info = " in #{o.locale}.#{o.key}" if o.locale && o.key
          message = " - #{o.message}" if o.message
          source = "\n  #{o.source.chomp.gsub("\n", "\n  ")}" if o.source
          puts "\n#{file_info}#{segment_info}: #{o.rule}#{message}#{source}"
        end
        puts "\n#{linter.offences.size} offences detected"
        exit 1
      end
    end
  end
end
