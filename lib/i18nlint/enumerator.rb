# frozen_string_literal: true

require_relative "cloneable_struct"
require_relative "yaml_with_lines"

require "i18n"

module I18nLint
  File = CloneableStruct.new(:filepath, :parsed, :raw, keyword_init: true) do
    def initialize(...)
      super
      @ext = ::File.extname(filepath)
      @is_ruby = @ext == ".rb"
      @is_yaml = @ext == ".yml" || @ext == ".yaml"
      @is_json = @ext == ".json"
    end

    def ruby? = @is_ruby
    def yaml? = @is_yaml
    def json? = @is_json
  end

  Segment = CloneableStruct.new(:file, :lineno, :key, :text, :value, :locale, :source_locale, keyword_init: true) do
    def filepath = file.filepath

    def source?
      locale.to_s == source_locale.to_s
    end

    def interpolations
      return [] if text.to_s.empty?

      handler = I18n.config.missing_interpolation_argument_handler
      keys = []
      I18n.config.missing_interpolation_argument_handler = proc { keys << _1 }
      I18n.interpolate(text, {})
      keys
    ensure
      I18n.config.missing_interpolation_argument_handler = handler
    end
  end

  # Using an I18n backend to load and parse the files ensures consistency in syntactical restrictions.
  class Backend < ::I18n::Backend::Simple
    # We're overloading so we can capture line numbers when parsing YAML.
    def suppress_warnings
      verbosity = $VERBOSE
      $VERBOSE = nil
      yield
    ensure
      $VERBOSE = verbosity
    end

    def load_file(filepath)
      yaml = Object.const_get(:YAML)
      suppress_warnings { Object.const_set(:YAML, YamlWithLines) }
      super
    ensure
      suppress_warnings { Object.const_set(:YAML, yaml) }
    end
  end

  # Yields each parsed file and segment by `:each_file` and `:each_segment` respectively. `:each` is not supported.
  class Enumerator
    attr_reader :source_locale

    def initialize(filepaths, source_locale:)
      @filepaths = Dir[*Array(filepaths).map(&:to_s)]
      @source_locale = source_locale

      @i18n_backend = Backend.new

      @parsed_files_by_filepath = {}
    end

    def num_files
      @filepaths.size
    end

    def each_file(&)
      ::Enumerator.new do |yielder|
        @filepaths.each do |filepath|
          yielder << @parsed_files_by_filepath[filepath] ||= File.new(
            filepath:,
            parsed: @i18n_backend.load_file(filepath),
            raw: ::File.read(filepath)
          )
        end
      end.each(&)
    end

    def each_segment(file: nil, &block)
      ::Enumerator.new do |yielder|
        each_file do |i18n_file|
          next if file && i18n_file != file

          YamlWithLines.walk(i18n_file.parsed, yield_hash_when:) do |(locale, *key_parts), text, line_start, _line_end|
            text, value = determine_text_and_value(text)
            yielder << Segment.new(file: i18n_file, lineno: line_start, key: key_parts.join("."), text:, value:,
                                   locale:, source_locale:)
          end
        end
      end.each(&block)
    end

    private

    def yield_hash_when
      proc do |hash|
        keys = hash.keys.map(&:to_s)
        keys.include?("one") && (keys.include?("few") || keys.include?("many") || keys.include?("other"))
      end
    end

    def determine_text_and_value(text)
      if text.is_a?(String)
        [text, nil]
      else
        [nil, text]
      end
    end
  end
end
