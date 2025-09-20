# frozen_string_literal: true

require "yaml"

module I18n
  module Lint
    # Run rules over the given files.
    class Linter
      attr_reader :offences, :filepaths, :source_locale

      def initialize(filepaths:, source_locale:)
        @offences = []
        @filepaths = Array(filepaths)
        @source_locale = source_locale
      end

      def run
        each_segment { |segment| run_segment(segment) }
        each_segment_comparison do |segment, source_segment|
          run_segment_comparison(segment.clone, source_segment.clone)
        end
        each_file { |i18n_file| run_file(i18n_file) }
        offences.concat(*Registry.rules.map(&:take_offences))
        self
      end

      def run_segment(segment)
        Registry.rules.each do |rule|
          rule.on_segment(segment.clone)
        end
      end

      def run_segment_comparison(segment, source_segment)
        Registry.rules.each do |rule|
          rule.on_segment_comparison(segment.clone, source_segment.clone)
        end
      end

      def run_file(i18n_file)
        Registry.rules.each do |rule|
          rule.on_file(i18n_file.clone)
        end
      end

      def walk_segments
        i18n_files.each do |item|
          item.parsed.each do |locale, data|
            data.each do |key, val|
              walk_values(key, val) do |full_key, text|
                yield Segment.new(file: item, lineno: "TODO", key: full_key, text:, locale: locale, source_locale:)
              end
            end
          end
        end
      end

      def each_segment
        @segment_keys_per_locale = Hash.new { |h, k| h[k] = Hash.new { |h, k| h[k] = [] } }
        walk_segments do |segment|
          @segment_keys_per_locale[segment.locale][segment.key] << segment
          yield segment
        end
      end

      def each_segment_comparison
        @segment_keys_per_locale.except(source_locale).each_value do |segments_per_key|
          segments_per_key.each do |key, segments|
            segments.each do |segment|
              @segment_keys_per_locale[source_locale][key].each do |source_segment|
                yield segment, source_segment
              end
            end
          end
        end
      end

      def each_file(&)
        i18n_files.each(&)
      end

      # Ensure cloning an instance also clones its members.
      module CloneableStruct
        def clone
          super.tap do |new_obj|
            self.class.members.each do |m|
              new_obj.send("#{m}=", send(m).clone)
            end
          end
        end
      end

      File = Struct.new(:filepath, :parsed, :yaml, keyword_init: true) do
        include CloneableStruct
      end

      Segment = Struct.new(:file, :lineno, :key, :text, :locale, :source_locale, keyword_init: true) do
        include CloneableStruct

        def filepath = file.filepath

        def source?
          locale == source_locale
        end
      end

      private

      def i18n_files
        @i18n_files ||= find_files.flat_map do |filepath|
          yaml = read_file(filepath)
          parsed = YAML.safe_load(yaml, filename: filepath, freeze: true)
          File.new(filepath: filepath.to_s, parsed:, yaml:)
        end
      end

      def find_files
        filepaths.flat_map do |filepath|
          Dir.glob(filepath)
        end
      end

      def read_file(filepath)
        ::File.read(filepath)
      rescue Errno::ENOENT
        nil
      end

      def walk_values(key, val, &)
        # TODO: use Enumerator.new with loop{}
        if val.is_a?(String) || val.nil?
          yield key, val
        else
          val.each { |nested_key, nested_val| walk_values("#{key}.#{nested_key}", nested_val, &) }
        end
      end
    end
  end
end
