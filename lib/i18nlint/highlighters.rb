# frozen_string_literal: true

require "i18nlint/highlighters/below_line"
require "i18nlint/highlighters/colour"

module I18nLint
  # Decide how to highlight a string.
  module Highlighters
    def self.indicate(text, *range)
      if $stdout.isatty
        Colour.indicate(text, *range)
      else
        BelowLine.indicate(text, *range)
      end
    end
  end
end
