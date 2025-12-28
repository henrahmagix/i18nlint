# frozen_string_literal: true

module I18nLint
  module Highlighters
    # Indicate slices in string. A 'slice' here is a tuple of character positions, e.g. '01234' and [1, 3] gives '123'.
    module BelowLine
      class << self
        def indicate(str, *slices, messages: [])
          slices = slices.sort
          messages = messages.dup

          has_messages = !messages.empty?

          ensure_tuples_of(Integer, *slices)

          # Go line-by-line to add indicators if needed, then join at the end.
          to_enum(:highlight_per_line, str, *slices).map do |line, slices_in_this_line|
            next line if slices_in_this_line.empty?

            indicators_line = make_indicators_line("^", slices_in_this_line,
                                                   (messages.shift(slices_in_this_line.size) if has_messages))

            "#{line.chomp}\n#{indicators_line}#{"\n" if line.end_with?("\n")}"
          end.join
        end

        private

        def ensure_tuples_of(type, *objects)
          return if objects.all? { _1.is_a?(Array) && _1.map(&:class) == [type, type] }

          raise ArgumentError,
                "must be given 1 or more tuples of #{type}, but was called with #{objects.map(&:inspect).join(", ")}"
        end

        def highlight_per_line(str, *slices)
          str.lines.reduce([0, []]) do |(checked, line_slices), line|
            line_length = line.chomp.length # ignore newlines so it doesn't look like we're indicating empty space

            slices.delete_if do |a, b|
              next if a > (limit = checked + line_length)

              # Adjust the slice so it's local to this line rather than the str as a whole.
              line_slices << [(a - checked).clamp(0, line_length), (b - checked).clamp(0, line_length)]
              true if b <= limit
            end

            yield [line, line_slices]

            [checked + line.length, []]
          end
        end

        def make_indicators_line(char, slices, messages)
          line = make_line_of(char, *slices)
          return line if messages.nil?

          "#{line} #{messages.map { |m| m.nil? ? "<nil>" : m }.join("; ")}".rstrip
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
