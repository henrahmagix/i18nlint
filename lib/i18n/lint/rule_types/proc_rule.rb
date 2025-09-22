# frozen_string_literal: true

module I18n
  module Lint
    module RuleTypes
      # Call the given Proc with teach segment; a truthy return value is an offence.
      class ProcRule < RuleType
        TYPE = Proc

        def proc = rule.input

        def on_segment(segment)
          return unless proc.call(segment.locale, segment.key, segment.text)

          rule.add_offence(segment)
        end
      end
    end
  end
end
