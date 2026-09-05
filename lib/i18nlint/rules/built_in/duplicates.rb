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

        def on_file(file)
          check_hash_key_duplicates_in_same_file(file)
        end

        def on_segment(segment)
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

        def check_hash_key_duplicates_in_same_file(file)
          YamlWithLines.dupe_segments_by_file[file.filepath].each_value do |dupes|
            offence_lineno, offence_column = dupes.last
            dupes[..-2].each do |(lineno, column)|
              source, highlight = get_source_highlight_from_parser_mark(file.raw, lineno, column)
              add_file_offence(file, "will be overwritten by value at line #{offence_lineno} column #{offence_column}",
                               lineno:, source:, highlight:)
            end
          end
        end

        def get_source_highlight_from_parser_mark(string, lineno, column)
          source = string.match(/\A(?:.*[\r\n]){#{lineno - 1}}(.{#{column}})/)[1]
          highlight = Regexp.last_match.offset(1)
          indent = source.match(/^\s*/)[0]
          source = source.delete_prefix(indent)
          highlight[0] += indent.length

          [source, highlight]
        end
      end
    end
  end
end
