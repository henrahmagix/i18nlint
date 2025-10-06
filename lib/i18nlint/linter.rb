# frozen_string_literal: true

require "yaml"

module I18nLint
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
      @tick_each_file = make_tick_proc(block)
    end

    def tick_each_comparison(&block)
      @tick_each_comparison = make_tick_proc(block)
    end

    def run
      each_file do |i18n_file|
        tick(@tick_each_file, Registry.rules.sum do |rule|
          next 0 if rule.excluded?(i18n_file.filepath)

          rule.on_file(i18n_file.clone)
          each_segment(file: i18n_file) do |segment|
            rule.on_segment(segment.clone)
          end
          rule.take_offences.tap { offences.concat(_1) }.size
        end)
      end
    end

    def run_comparison
      each_segment_comparison do |segment, source_segment|
        tick(@tick_each_comparison, Registry.rules.sum do |rule|
          next 0 if rule.excluded?(segment.file.filepath)

          rule.on_segment_comparison(segment.clone, source_segment.clone)
          rule.take_offences.tap { offences.concat(_1) }.size
        end)
      end
    end

    def each_file(&)
      @enum.each_file do |file|
        yield file
      rescue Error # coming from a segment?
        raise
      rescue StandardError => e
        raise ErrorOnFile.new file, e
      end
    end

    def each_segment(file: nil, &)
      @enum.each_segment(file:) do |segment|
        yield segment
      rescue StandardError => e
        raise ErrorOnSegment.new segment, e
      end
    end

    def each_segment_comparison(&)
      comparisons = ComparisonMap.new(source_locale)
      # Slurp all the files first, so we can separate the source segments from translation segments.
      each_segment { comparisons.add(_1) }
      comparisons.freeze
      comparisons.each do |segment, source_segment|
        yield [segment, source_segment]
      rescue StandardError => e
        raise ErrorOnSegmentComparison.new segment, source_segment, e
      end
    end

    private

    def tick(block, num_offences)
      return if block.nil?

      block.call(num_offences)
    end

    def make_tick_proc(block)
      if block.arity.zero?
        ->(_num_offences) { block.call }
      else
        block
      end
    end

    # Store segments then enumerate them compared to the source_locale.
    class ComparisonMap
      def initialize(source_locale)
        @source_locale = source_locale.downcase
        @hash = Hash.new do |h, k|
          next if h.frozen?

          h[k] = Hash.new do |h, k|
            next if h.frozen?

            h[k] = []
          end
        end
      end

      attr_reader :source_locale

      include Enumerable

      def each(&)
        ::Enumerator.new do |yielder|
          each_segment do |segment|
            each_source(segment.key) do |source_segment|
              yielder << [segment, source_segment]
            end
          end
        end.each(&)
      end

      def add(segment)
        @hash[segment.locale.downcase.to_sym][segment.key] << segment
      end

      def freeze
        super
        @hash.freeze
        @hash.each_value do |level2|
          level2.freeze
          level2.each_value(&:freeze)
        end
      end

      private

      def each_segment(&block)
        @hash.except(source_locale.to_sym).each_value do |per_key|
          per_key.each_value do |segments|
            segments.each(&block)
          end
        end
      end

      def each_source(key, &)
        @hash.dig(source_locale.to_sym, key)&.each(&)
      end
    end
  end
end
