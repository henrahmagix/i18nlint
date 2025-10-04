# frozen_string_literal: true

module I18nLint
  module Rules
    module BuiltIn
      # Helper methods for reporting offences for a pattern configuration.
      module MatchPattern
        def self.included(base)
          base.on_init do
            next unless config.is_a?(Hash) && config["Pattern"]

            options = Regexp::IGNORECASE if config["CaseSensitive"] == false
            @pattern = Regexp.new(config["Pattern"], options)
          end
        end

        attr_reader :pattern

        def description = pattern.inspect
      end

      # Report when a Regexp pattern matches against an individual segment.
      class MatchSegment < Rule
        def self.rule_key = "match-segment"

        include MatchPattern

        def on_segment(segment)
          return unless pattern

          segment.text.scan(pattern) do |_match|
            add_segment_offence(segment, nil, highlight: Regexp.last_match.offset(0))
          end
        end
      end

      # Report when a Regexp pattern matches against an individual segment as compared to itself in the source locale.
      class MismatchToSource < Rule
        def self.rule_key = "mismatch-to-source"

        include MatchPattern

        def on_segment_comparison(segment, source_segment)
          return unless pattern

          mismatches = enum_for(:each_mismatch, segment.text, source_segment.text).to_a
          return if mismatches.none?

          add_segment_compare_offence(
            segment, source_segment,
            "Found #{mismatches.size == 1 ? "mismatch" : "mismatches"} to the source #{source_segment.locale.upcase}",
            highlight: mismatches.filter_map(&:highlight),
            source_highlight: mismatches.filter_map(&:source_highlight)
          )
        end

        private

        def scan(text)
          text.enum_for(:scan, pattern).map { Scan.new(_1, Regexp.last_match.offset(0)) }
        end
        Scan = Struct.new(:match, :highlight)
        private_constant :Scan

        def reduce(trans, source)
          trans.delete_if do |scan|
            if (i = source.find_index { _1.match == scan.match })
              source.delete_at(i)
              next true
            end
          end
        end

        def scan_and_reduce(trans, source)
          trans = scan(trans) # 🏳️‍⚧️🏳️‍🌈🫶
          source = scan(source)
          reduce(trans, source)

          [trans, source]
        end

        def each_mismatch(trans, source)
          trans, source = scan_and_reduce(trans, source)

          trans_tally = trans.map(&:match).tally
          source_tally = source.map(&:match).tally

          trans.each  { |scan| yield mismatch_from_tallies(scan.match, trans_tally, source_tally, scan.highlight, nil) }
          source.each { |scan| yield mismatch_from_tallies(scan.match, trans_tally, source_tally, nil, scan.highlight) }
        end

        def mismatch_from_tallies(match, trans_tally, source_tally, highlight, source_highlight)
          Mismatch.new(match, trans_tally[match] || 0, source_tally[match] || 0, highlight, source_highlight)
        end
        Mismatch = Struct.new(:match, :actual_count, :expected_count, :highlight, :source_highlight)
        private_constant :Mismatch
      end

      # Report when a Regexp pattern matches against a whole I18n file.
      class MatchFile < Rule
        def self.rule_key = "match-file"

        include MatchPattern

        def on_file(file)
          return unless pattern

          file.raw.scan(pattern) do
            source, lineno, offset_adjust = source_for_match(Regexp.last_match, file.raw)
            highlight = Regexp.last_match.offset(0).map { _1 - offset_adjust }
            add_file_offence(file, nil, lineno:, source:, highlight:)
          end
        end

        def source_for_match(match, raw)
          end_of_match = match.offset(0)[1]
          n = 0
          lines = []
          raw.lines.each do |line|
            break if n >= end_of_match

            lines << line
            n += line.length
          end

          [lines.last, lines.size, n - lines.last.size]
        end
      end
    end
  end
end
