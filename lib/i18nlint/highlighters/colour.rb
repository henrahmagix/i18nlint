# frozen_string_literal: true

module I18nLint
  module Highlighters
    # Colour slices in string. A 'slice' here is a tuple of character positions, e.g. '01234' and [1, 3] gives '123'.
    module Colour
      class << self
        def bold(str)
          "\e[1m#{str}\e[0m"
        end

        def highlight(str)
          "\e[30;43m#{str}\e[0m"
        end

        def indicate(str, *slices)
          ensure_tuples_of(Integer, *slices)

          str = str.dup

          slices.sort.reverse.each do |slice|
            str[slice[0]...slice[1]] = highlight(str[slice[0]...slice[1]])
          end

          str
        end

        private

        def ensure_tuples_of(type, *objects)
          return if objects.all? { _1.is_a?(Array) && _1.map(&:class) == [type, type] }

          raise ArgumentError, "must be given 1 or more tuples of #{type}, but was called with #{arrays.inspect}"
        end
      end
    end
  end
end
