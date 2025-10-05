# frozen_string_literal: true

module I18nLint
  module Rules
    module BuiltIn
      # Compare interpolations against source; anything extra or missing is an offence.
      class Interpolations < Rule
        def on_segment_comparison(segment, source_segment)
          these_keys, source_keys = [segment, source_segment].map(&:interpolations)
          return if these_keys == source_keys

          msg = []
          unless (extra = these_keys - source_keys).empty?
            msg << "extra in #{segment.locale}: #{extra.join(", ")}"
          end

          unless (missing = source_keys - these_keys).empty?
            msg << "missing in #{segment.locale}: #{missing.join(", ")}"
          end

          add_segment_compare_offence(segment, source_segment, msg.join("; ")) unless msg.empty?
        end
      end
    end
  end
end
