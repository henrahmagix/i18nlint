# frozen_string_literal: true

require "yaml"

module I18n
  module Lint
    # Run rules over the given files.
    class Linter
      attr_reader :offences, :source_locale

      def initialize(filepaths:, source_locale:)
        @offences = []
        @enum = Enumerator.new(filepaths, source_locale:)
        @source_locale = source_locale
      end

      def num_files
        @enum.num_files
      end

      def tick_each_file(&block)
        @tick_each_file =
          if block.arity.zero?
            ->(_no_offences) { block.call }
          else
            block
          end
      end

      def run
        @segment_keys_per_file_locale = new_hash_array_three_levels
        @enum.each_file do |i18n_file|
          new_offences_count = Registry.rules.reject { _1.excluded?(i18n_file.filepath) }.sum do |rule|
            run_file(i18n_file, rule)
            rule.take_offences.tap { offences.concat(_1) }.size
          end
          tick(new_offences_count)
        end
        self
      end

      def each_file(&)
        @enum.each_file(&)
      end

      def each_segment(&)
        @enum.each_segment(&)
      end

      private

      def tick(num_offences)
        return if @tick_each_file.nil?

        @tick_each_file.call(num_offences)
      end

      def run_file(i18n_file, rule)
        rule.on_file(i18n_file.clone)
        @enum.each_segment(file: i18n_file) do |segment|
          @segment_keys_per_file_locale[i18n_file][segment.locale][segment.key] << segment
          rule.on_segment(segment.clone)
        end
        each_segment_comparison(i18n_file) do |segment, source_segment|
          rule.on_segment_comparison(segment.clone, source_segment.clone)
        end
      end

      def each_segment_comparison(file)
        @segment_keys_per_file_locale[file].except(source_locale).each_value do |segments_per_key|
          segments_per_key.each do |key, segments|
            segments.each do |segment|
              @segment_keys_per_file_locale[file][source_locale][key].each do |source_segment|
                yield segment, source_segment
              end
            end
          end
        end
      end

      def new_hash_array_three_levels
        Hash.new do |h, k|
          h[k] = Hash.new do |h, k|
            h[k] = Hash.new do |h, k|
              h[k] = []
            end
          end
        end
      end
    end
  end
end
