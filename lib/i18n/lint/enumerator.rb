# frozen_string_literal: true

require "yaml"
require_relative "cloneable_struct"

module I18n
  module Lint
    File = CloneableStruct.new(:filepath, :parsed, :yaml, keyword_init: true)

    Segment = CloneableStruct.new(:file, :lineno, :key, :text, :locale, :source_locale, keyword_init: true) do
      def filepath = file.filepath

      def source?
        locale == source_locale
      end
    end

    # Yields each parsed file and segment by `:each_file` and `:each_segment` respectively. `:each` is not supported.
    class Enumerator
      def initialize(filepaths, source_locale:)
        @read_files_by_filepath = read_all_files(Array(filepaths).map(&:to_s))
        @source_locale = source_locale

        @parsed_files_by_filepath = {}
        @segments_by_filepath = Hash.new { |h, filepath| h[filepath] = [] }
      end

      def each_file(&)
        enum = ::Enumerator.new do |yielder|
          @read_files_by_filepath.each do |filepath, yaml|
            yielder << @parsed_files_by_filepath[filepath] ||= parse_yaml(yaml, filepath:)
          end
        end
        block_given? ? enum.each(&) : enum
      end

      def each_segment(&)
        enum = ::Enumerator.new do |yielder|
          each_file do |file|
            walk_file(file) do |locale, full_key, text|
              segment = Segment.new(file:, lineno: "TODO", key: full_key, text:, locale:, source_locale:)
              yielder << segment
            end
          end
        end
        block_given? ? enum.each(&) : enum
      end

      private

      attr_reader :source_locale

      def read_all_files(filepaths)
        filepaths.flat_map { Dir.glob(_1) }
                 .uniq
                 .map { |filepath| [filepath, read_file(filepath)] }
                 .compact
                 .to_h
      end

      def read_file(filepath)
        ::File.read(filepath)
      rescue Errno::ENOENT
        warn "cannot read file: #{filepath.inspect}"
        nil
      end

      def parse_yaml(yaml, filepath:)
        parsed = YAML.safe_load(yaml, filename: filepath, freeze: true)
        File.new(filepath:, parsed:, yaml:)
      end

      def walk_file(file)
        file.parsed.each do |locale, values|
          values.each do |key, val|
            walk_segments(key, val) do |full_key, text|
              yield locale, full_key, text
            end
          end
        end
      end

      def walk_segments(key, val, &)
        if val.is_a?(String) || val.nil?
          yield key, val
        else
          val.each { |nested_key, nested_val| walk_segments("#{key}.#{nested_key}", nested_val, &) }
        end
      end
    end
  end
end
