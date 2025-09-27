# frozen_string_literal: true

module I18nLint
  # A single error wrapping multiple error messages without their stacktraces. Should only be used for printing.
  class ConfigurationProblems < Error
    def initialize(errors)
      super(errors.map(&:message).join("\n"))
    end
  end

  Configuration = Struct.new(:source_locale, :requires, :rule_options, keyword_init: true) do
    def load_from_argv_and_file!
      parse_argv
      self.rule_options = load_rule_options_from_file
      self.requires = rule_options.delete("require")
      @remaining_rule_options = rule_options.dup
    end

    attr_reader :help, :config_file_does_not_exist, :remaining_rule_options

    def register_rules!
      require_relative_from = ::File.dirname(config_filepath || Dir.pwd)
      requires.each do |path|
        require ::File.expand_path(path, require_relative_from)
      end

      register_built_in("match-segment", Rules::BuiltIn::MatchSegment)
      register_built_in("match-file", Rules::BuiltIn::MatchFile)
      register_built_in("match-segment-to-source", Rules::BuiltIn::MatchSegmentToSource)

      problems = register_rule_subclasses
      raise ConfigurationProblems, problems unless problems.empty?
    end

    private

    def parse_argv
      parser = OptionParser.new do |parser|
        parser.banner = "Usage: i18nlint files... --source=LOCALE --config=path/to/.i18nlint.yml"

        parser.on("--source=LOCALE", "The locale to configure segment comparisons against source.") do |v|
          self.source_locale = v
        end
        parser.on("--config=CONFIG", "The configuration of rules.") do |v|
          @config_filepath = v
        end
      end.tap(&:parse!)
      @help = parser.help
    end

    def config_filepath
      @config_filepath ||= [
        ::File.join(Dir.pwd, ".i18nlint.yml"),
        ::File.join(Dir.home, ".i18nlint.yml")
      ].find { |f| ::File.exist?(f) }
    end

    def load_rule_options_from_file
      return if config_filepath.nil?

      ::YAML.safe_load_file(config_filepath)
    rescue ::Errno::ENOENT
      @config_file_does_not_exist = config_filepath
      {}
    end

    def register_built_in(key, klass)
      @remaining_rule_options.delete(key)&.each do |conf|
        register_from_require_options(conf, klass)
      end
    end

    def register_from_require_options(conf, klass)
      enabled = conf.delete("Enabled")
      enabled = klass.enabled_by_default? if enabled.nil?
      Registry.register_rule(klass, conf) if enabled
    end

    def register_rule_subclasses
      Rule.subclasses.filter_map do |klass|
        conf = {}
        conf.merge! @remaining_rule_options.delete(klass.rule_key) || {} if klass.rule_key

        register_from_require_options(conf, klass)
        nil
      rescue RuleTypes::ClassRule::WillNeverRun => e
        e unless klass.rule_key.empty?
      rescue Error => e
        e
      end
    end
  end
end
