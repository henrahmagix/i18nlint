# frozen_string_literal: true

module I18nLint
  module Highlighters
    # Indicate slices in string. A 'slice' here is a tuple of character positions, e.g. '01234' and [1, 3] gives '123'.
    module BelowLine
      class << self
        def indicate(str, *slices)
          ensure_tuples_of(Integer, *slices)

          # Go line-by-line to add indicators if needed, then join at the end.
          highlight_per_line(str, *slices).map do |line, slices_in_this_line|
            next line if slices_in_this_line.empty?

            indicators_line = make_line_of("^", *slices_in_this_line)

            if line.end_with?("\n")
              "#{line}#{indicators_line}\n"
            else
              "#{line}\n#{indicators_line}"
            end
          end.join
        end

        private

        def ensure_tuples_of(type, *objects)
          return if objects.all? { _1.is_a?(Array) && _1.map(&:class) == [type, type] }

          raise ArgumentError, "must be given 1 or more tuples of #{type}, but was called with #{objects.inspect}"
        end

        def highlight_per_line(str, *slices)
          ::Enumerator.new do |yielder|
            checked = 0 # use this to adjust slices to the line being checked

            str.lines.each do |line|
              yielder << [line, slices.select { |_, n| n > checked && n <= checked + line.length }.map do |slice|
                # Adjust the slice so it's local to this line rather than the str as a whole.
                slice.map { |pos| pos - checked }
              end]
            ensure
              checked += line.length
            end
          end
        end

        def make_line_of(char, *slices)
          (" " * slices.last[1]).tap do |line|
            slices.each do |slice|
              line[slice[0]...slice[1]] = char * (slice[1] - slice[0])
            end
          end
        end
      end
    end
  end
end
