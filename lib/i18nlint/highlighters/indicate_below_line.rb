# frozen_string_literal: true

module I18nLint
  module Highlighters
    # Indicate slices in string. A 'slice' here is a tuple of character positions, e.g. '01234' and [1, 3] gives '123'.
    module IndicateBelowLine
      def self.indicate(str, *slices) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        unless slices.first.is_a?(Array)
          raise ArgumentError,
                "highlight_slice must be called with 1 or more arrays, but was called with #{slices.inspect}"
        end

        string_length_checked = 0 # use this to adjust slices to the line being checked

        # Go line-by-line to add indicators if needed, then join at the end.
        lines = str.each_line.to_a
        lines_with_indicators = lines.map.with_index do |line, i|
          string_length_checked += lines[i - 1].length unless i.zero?

          # Find the slices to indicate on this line, if any.
          slices_in_this_line = slices.map do |slice|
            next unless slice[1] > string_length_checked && slice[1] <= string_length_checked + line.length

            # Adjust the slice so it's local to this line rather than the str as a whole.
            slice.map { |pos| pos - string_length_checked }
          end.compact

          next line if slices_in_this_line.empty?

          # Build an indicator line full of spaces long enough to contain all indicators.
          indicators_line = " " * slices_in_this_line.last[1]

          # Replace the same character positions in our indicator line with ^.
          slices_in_this_line.each do |slice|
            from   = slice[0]
            to     = slice[1]
            length = to - from

            indicators_line[from...to] = "^" * length
          end

          if line.end_with?("\n")
            "#{line}#{indicators_line}\n"
          else
            "#{line}\n#{indicators_line}"
          end
        end

        lines_with_indicators.join
      end
    end
  end
end
