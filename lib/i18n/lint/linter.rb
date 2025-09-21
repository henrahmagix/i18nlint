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

      def run
        each_segment { |segment| run_segment(segment) }
        each_segment_comparison do |segment, source_segment|
          run_segment_comparison(segment.clone, source_segment.clone)
        end
        each_file { |i18n_file| run_file(i18n_file) }
        offences.concat(*Registry.rules.map(&:take_offences))
        self
      end

      def each_segment
        @segment_keys_per_locale = Hash.new { |h, k| h[k] = Hash.new { |h, k| h[k] = [] } }
        @enum.each_segment do |segment|
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
        @enum.each_file(&)
      end

      private

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
    end
  end
end
