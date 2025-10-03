# frozen_string_literal: true

module I18nLint
  # Central store of which locale is the source (only useful for comparative rules) and loading + registering rules.
  class Configuration
    def initialize(source_locale: "", rule_options: {}, requires: [])
      @source_locale = source_locale.upcase
      @rule_options = rule_options
      @requires = requires
    end

    def load_from_argv_and_file!
      parse_argv
      @rule_options.merge!(load_rule_options_from_file)
      @remaining_rule_options = rule_options.dup
      @requires += @remaining_rule_options.delete("require") || []
    end

    def on_problems(&block)
      @on_problems = block
    end

    def help = @parser.help

    attr_reader :source_locale, :requires, :rule_options,
                :config_file_does_not_exist, :remaining_rule_options

    def register_rules!
      require_relative_from = ::File.dirname(config_filepath || Dir.pwd)
      requires.each do |path|
        require ::File.expand_path(path, require_relative_from)
      end

      register_built_ins

      problems = register_rule_subclasses
      problems.each { @on_problems.call(_1) } if @on_problems
    end

    private

    def parse_argv
      @parser = OptionParser.new do |parser|
        parser.banner = "Usage: i18nlint files... --source=LOCALE --config=path/to/.i18nlint.yml"

        parser.on("--source=LOCALE", "The locale to configure segment comparisons against source.") do |v|
          @source_locale = v.upcase
        end
        parser.on("--config=CONFIG", "The configuration of rules.") do |v|
          warn "Ignoring --config=#{@config_filepath}" if @config_filepath
          @config_filepath = v
        end
      end.tap(&:parse!)
    end

    def config_filepath
      @config_filepath ||= [
        ::File.join(Dir.pwd, ".i18nlint.yml"),
        ::File.join(Dir.home, ".i18nlint.yml")
      ].find { |f| ::File.exist?(f) }
    end

    def load_rule_options_from_file
      return {} if config_filepath.nil?

      ::YAML.safe_load_file(config_filepath)
    rescue ::Errno::ENOENT
      @config_file_does_not_exist = config_filepath
      {}
    end

    def find_built_in = proc { _1.name.start_with?(Rules::BuiltIn.name) }

    def register_built_ins
      Rule.subclasses.select(&find_built_in).each do |klass|
        @remaining_rule_options.delete(klass.rule_key)&.each do |conf|
          register_from_options(conf, klass)
        end
      end
    end

    def register_from_options(conf, klass)
      enabled = conf.delete("Enabled")
      enabled = klass.enabled_by_default? if enabled.nil?
      Registry.register_rule(klass, conf) if enabled
    end

    def register_rule_subclasses
      Rule.subclasses.reject(&find_built_in).filter_map do |klass|
        conf = @remaining_rule_options.delete(klass.rule_key) if klass.rule_key
        conf ||= {}

        register_from_options(conf, klass)
        nil
      rescue RuleTypes::ClassRule::WillNeverRun => e
        e unless klass.rule_key.empty?
      rescue Error => e
        e
      end
    end
  end
end
