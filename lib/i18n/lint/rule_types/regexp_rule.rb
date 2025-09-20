# frozen_string_literal: true

module I18n
  module Lint
    module RuleTypes
      # Match the given regexp against each segment; a match is an offence.
      class RegexpRule < RuleType
        TYPE = Regexp

        def regexp = rule.config

        def on_segment(segment)
          return unless segment.text.match?(regexp)

          rule.add_offence(segment)
        end
      end
    end
  end
end
