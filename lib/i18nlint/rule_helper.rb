# frozen_string_literal: true

module I18nLint
  # Various methods to help construct rules.
  module RuleHelper
    # For each item in arr_a, find the first comparable item in arr_b and remove them both. Returns the removed items.
    def xor!(arr_a, arr_b, &compare)
      compare = xor_comparison_proc(&compare)

      deleted = []

      arr_a.delete_if do |a|
        if (i = arr_b.find_index { |b| compare[a, b] })
          deleted << [a, arr_b[i]]
          arr_b.delete_at(i)
          next true
        end
      end

      [deleted.map(&:first), deleted.map(&:last)]
    end

    def xor_comparison_proc(&block)
      if !block_given?
        proc { |a, b| a == b }
      elsif block.arity != 2
        proc { |a, b| block[a] == block[b] }
      else
        block
      end
    end
    private :xor_comparison_proc

    def match_with_highlights(string, regex)
      string.enum_for(:scan, regex).map do |matches|
        [matches[0], Regexp.last_match.offset(0)]
      end
    end

    # Use this to XOR results found using `match_with_highlights`.
    def xor_highlights!(arr_a, arr_b) = xor!(arr_a, arr_b, &:first)

    def self.included(base) = base.extend ClassMethods

    module ClassMethods # rubocop:disable Style/Documentation
      def def_segment_comparison(includes_highlights: false, message: nil, source_message: nil, &process_segment)
        include EasySegmentComparison
        include includes_highlights ? CompareWithHighlights : CompareNoHighlights

        define_method(:process_message) { message }
        define_method(:process_source_message) { source_message }
        define_method(:process_segment, &process_segment)
      end

      module CompareNoHighlights # rubocop:disable Style/Documentation
        def compare!(these, source) = xor!(these, source)
        def process_values(values) = values
        def process_highlights(_values) = nil
      end

      module CompareWithHighlights # rubocop:disable Style/Documentation
        def compare!(these, source) = xor!(these, source, &:first)
        def process_values(values) = values.map(&:first)

        def process_highlights(values)
          highlights = values.map(&:last)
          highlights.empty? ? nil : highlights
        end
      end

      module EasySegmentComparison # rubocop:disable Style/Documentation
        def on_segment_comparison(segment, source_segment)
          these = process_segment(segment)
          source = process_segment(source_segment)

          compare!(these, source)

          return if these.empty? && source.empty?

          add_segment_compare_offence(
            segment, source_segment,
            string_or_callable(process_message, process_values(these), segment, source_segment),
            string_or_callable(process_source_message, process_values(source), segment, source_segment),
            highlight: process_highlights(these), source_highlight: process_highlights(source)
          )
        end

        private

        def string_or_callable(val, *args)
          val = val.call(*args) if val.is_a? Proc
          val
        end
      end
    end
  end
end
