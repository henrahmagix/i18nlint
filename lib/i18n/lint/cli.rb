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
            if rule_class.name.nil? || rule_class.name.empty?
              warn "I18n::Lint::Rule subclass must have ::name defined to accept configuration: #{rule_class}"
              next
            end

            rule_key = rule_class.name.delete_prefix("::").delete_prefix("I18n::Lint::Rule::").gsub("::", "/")
            rule_conf = conf.delete(rule_key) || {}
            if rule_conf["Enabled"] == true || (rule_class.enabled_by_default? && rule_conf["Enabled"] != false)
              Registry.register_rule(rule_class, rule_conf)
            end
          end

          conf.each_key do |key|
            warn "Unused configuration: #{key.inspect}"
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
          segment_info = " in #{o.locale}.#{o.key}" if o.locale && o.key
          message = " - #{o.message}" if o.message
          puts <<~MSG.chomp

            #{o.filepath}:#{o.lineno}: #{o.rule}#{segment_info}#{message}
              #{o.source.chomp.gsub("\n", "\n  ")}
          MSG
        end
        puts "\n#{linter.offences.size} offences detected"
        exit 1
      end
    end
  end
end
