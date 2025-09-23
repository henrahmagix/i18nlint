# frozen_string_literal: true

module I18n
  module Lint
    module Rules
      module BuiltIn
        # Helper methods for reporting offences for a pattern configuration.
        module MatchPattern
          def self.included(base)
            base.on_init do
              next unless config["Pattern"]

              options = Regexp::IGNORECASE if config["CaseSensitive"] == false
              @pattern = Regexp.new(config["Pattern"], options)
            end
          end

          attr_reader :pattern

          def description = pattern.inspect
        end

        # Report when a Regexp pattern matches against an individual segment.
        class MatchSegment < Rule
          include MatchPattern

          def on_segment(segment)
            return unless pattern

            segment.text.scan(pattern) do |_match|
              add_segment_offence(segment, nil)
            end
          end
        end

        # Report when a Regexp pattern matches against a whole YAML file.
        class MatchFile < Rule
          include MatchPattern

          def on_file(file)
            return unless pattern

            file.yaml.scan(pattern) do |_match|
              lineno = Regexp.last_match.offset(0)[0]
              lines = file.yaml[0..lineno].lines
              add_file_offence(file, nil, lineno: lines.size, source: lines.last)
            end
          end
        end
      end
    end
  end
end
