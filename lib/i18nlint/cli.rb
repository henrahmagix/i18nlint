# frozen_string_literal: true

require "optparse"
require "yaml"

require "i18nlint"

module I18nLint
  # Run the linter in your terminal.
  class CLI
    def self.run(...) = new.run(...)

    def config(args) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      Configuration.new(args).tap do |conf|
        conf.on_problems { |e| warn e.message }

        conf.load_from_argv_and_file!

        if conf.source_locale.to_s.empty?
          warn conf.help
          exit 1
        end

        if conf.config_file_does_not_exist
          warn "Config file does not exist: #{conf.config_file_does_not_exist}"
          warn conf.help
          exit 1
        end

        conf.register_rules!
        conf.remaining_rule_options.each_key do |key|
          warn "Unused configuration #{key.inspect} expects class #{key.gsub("/", "::")} to subclass I18nLint::Rule. " \
               "If this is a rule you're expecting to be used, that means it hasn't been loaded in the `require:` " \
               "list, or it doesn't subclass I18nLint::Rule."
          warn
        end
      end
    end

    def run(args = []) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      conf = config(args)
      linter = Linter.new(filepaths: conf.filepaths, source_locale: conf.source_locale)

      if linter.num_files.zero?
        puts "No files given"
        exit 0
      end

      if Registry.rules.empty?
        puts "No rules configured"
        exit 0
      end

      tick = ->(num_offences) { print num_offences.zero? ? "." : "F" }
      linter.tick_each_file(&tick)
      linter.tick_each_comparison(&tick)

      puts "Inspecting #{linter.num_files} files"
      linter.run
      puts "\nComparing segments to source #{conf.source_locale}"
      linter.run_comparison
      puts "\n\n"

      if linter.offences.empty?
        puts "No offences detected"
        exit 0
      end

      puts "Offences:\n\n"
      puts linter.offences.map { format_offence(_1) }.join("\n\n")
      puts "\n#{linter.offences.size} offences detected"
      exit 1
    end

    FILE_OFFENCE_DISPLAY = <<~MSG
      %<filepath>s:%<lineno>s: %<rule>s: %<message>s
      %<text_indented>s
    MSG

    SEGMENT_OFFENCE_DISPLAY = <<~MSG
      %<filepath>s:%<lineno>s in %<locale>s.%<key>s: %<rule>s: %<message>s
      %<text_indented>s
    MSG

    COMPARE_SEGMENT_OFFENCE_DISPLAY = <<~MSG # 🏳️‍⚧️🏳️‍🌈🫶
      Comparison: %<rule>s
      %<trans_filepath>s:%<trans_lineno>s in %<trans_locale>s.%<trans_key>s: %<trans_message>s
      %<trans_text_indented>s
      %<source_filepath>s:%<source_lineno>s in %<source_locale>s.%<source_key>s: %<source_message>s
      %<source_text_indented>s
    MSG

    private

    def format_offence(offence)
      o = offence_hash_for_formatting(offence)

      case offence
      when FileOffence then FILE_OFFENCE_DISPLAY % o
      when SegmentOffence then SEGMENT_OFFENCE_DISPLAY % o
      when CompareSegmentOffence
        source = offence_hash_for_formatting(offence.source_offence)

        COMPARE_SEGMENT_OFFENCE_DISPLAY % rename_keys(o, 'trans_\0').merge(rename_keys(source, 'source_\0'))
      end.gsub(/:? +$/, "").strip
    end

    def offence_hash_for_formatting(offence)
      o = offence.to_h
      o[:text] = highlight(o[:text], offence.highlight)
      indent(o)
    end

    def indent(hash)
      hash.keys.each do |k|
        hash[:"#{k}_indented"] = "  #{hash[k].to_s.chomp.gsub("\n", "\n  ")}"
      end
      hash
    end

    def rename_keys(hash, gsub)
      hash.transform_keys! { _1 == :rule ? _1 : _1.to_s.gsub(/^(.*)$/, gsub).to_sym }
    end

    def highlight(text, range)
      return text if range.nil? || range.to_a.empty?

      range = [range] unless range[0].is_a?(Array)

      Highlighters.indicate(text, *range)
    end
  end
end
