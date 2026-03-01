# frozen_string_literal: true

require_relative "cloneable_struct"
require_relative "yaml_with_lines"

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
  end

  # Using an I18n backend to load and parse the files ensures consistency in syntactical restrictions. We're overloading
  # so we can capture line numbers where possible.
  class Loader < ::I18n::Backend::Simple
    # We don't need to store the translations.
    def store_translations(...); end

    def load_yml(...)
      ::I18n::Backend.const_set(:YAML, YamlWithLines)
      super
    ensure
      ::I18n::Backend.send(:remove_const, :YAML)
    end
  end

  # Yields each parsed file and segment by `:each_file` and `:each_segment` respectively. `:each` is not supported.
  class Enumerator
    attr_reader :source_locale

    def initialize(filepaths, source_locale:)
      @filepaths = Dir[*Array(filepaths).map(&:to_s)]
      @source_locale = source_locale

      @i18n_loader = Loader.new

      @files = {}
    end

    def num_files
      @filepaths.size
    end

    def each_file
      return to_enum(__method__) { @filepaths.size } unless block_given?

      @filepaths.each do |filepath|
        yield @files[filepath] ||= File.new(
          filepath:,
          parsed: @i18n_loader.send(:load_file, filepath),
          raw: ::File.read(filepath)
        )
      end
    end

    def each_segment(file: nil)
      return to_enum(__method__, file:) unless block_given?

      each_file do |i18n_file|
        next if file && i18n_file != file

        YamlWithLines.walk(i18n_file.parsed, yield_hash_when:) do |(locale, *key_parts), text, line_start, _line_end|
          text, value = determine_text_and_value(text)
          yield Segment.new(file: i18n_file, lineno: line_start, key: key_parts.join("."), text:, value:,
                            locale:, source_locale:)
        end
      end
    end

    private

    def yield_hash_when
      proc do |hash|
        hash_key?(hash, :one) && (hash_key?(hash, :few) || hash_key?(hash, :many) || hash_key?(hash, :other))
      end
    end

    def hash_key?(hash, key)
      hash.key?(key.to_s) || hash.key?(key.to_sym)
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
