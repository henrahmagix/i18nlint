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
              source, lineno = source_for_match(Regexp.last_match, file.yaml)
              add_file_offence(file, nil, lineno:, source:)
            end
          end

          def source_for_match(match, yaml)
            end_of_match = match.offset(0)[1]
            n = 0
            lines = []
            yaml.lines.each do |line|
              break if n >= end_of_match

              lines << line
              n += line.length
            end

            [lines.last, lines.size]
          end
        end
      end
    end
  end
end
