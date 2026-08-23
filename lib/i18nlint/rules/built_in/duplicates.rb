# frozen_string_literal: true

module I18nLint
  module Rules
    module BuiltIn
      # Check for duplicate segment keys across all given files. Differing load order determines which duplicate segment
      # is the last added to the I18n store, so don't bother reporting on that; just highlight all the duplicates.
      class Duplicates < Rule
        enable_by_default true

        # Track every segment key. Add offence when any key is encountered twice or more. Ensure the first occurrence is
        # offended, and only once.
        on_init do
          @keys = Set.new
          @offended_first_occurrence = Hash.new { |h, locale| h[locale] = {} }
        end
        attr_reader :keys, :offended_first_occurrence

        def on_segment(segment)
          check_file_duplicates(segment)

          first_occurrence = recorded_first_occurrence(segment)
          return if first_occurrence == true

          add_segment_offence(first_occurrence) if first_occurrence
          add_segment_offence(segment)
        end

        private

        def recorded_first_occurrence(segment)
          if keys.add?([segment.locale, segment.key])
            offended_first_occurrence[segment.locale][segment.key] = segment
            return true
          end

          offended_first_occurrence[segment.locale].delete(segment.key)
        end

        def check_file_duplicates(segment)
          dupes = YamlWithLines.dupe_segments_by_file.dig(segment.file.filepath, "#{segment.locale}.#{segment.key}")
          return unless dupes

          add_segment_offence(segment, "duplicate of line #{(dupes - [segment.lineno]).join(", ")}")
        end
      end
    end
  end
end
