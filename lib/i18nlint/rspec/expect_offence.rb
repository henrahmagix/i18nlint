# frozen_string_literal: true

require "tempfile"

module I18nLint
  module RSpec
    # Include in RSpec example groups to get rule assertions.
    module ExpectOffence
      def self.included(base)
        base.let(:rule) { ::I18nLint::Registry.register_rule(*[described_class, (config if defined?(config))].compact) }
      end

      extend ::RSpec::Matchers::DSL

      matcher :cause_offence do |expected|
        diffable
        supports_block_expectations

        chain(:type) { @type = _1 }
        chain(:did_you_mean) { @opposite_assertion = _1 }

        define_method(:source) { @source ||= expected.lines.grep_v(/^\s*\^+ ?/).join }

        def matches_offences?
          @actual, @offences = @actual.call(source)
          actual == expected
        end

        match              { matches_offences? && !@offences.empty? }
        match_when_negated { matches_offences? && @offences.empty? }

        failure_message do
          if source == expected
            return "No offence highlights have been given#{", and none were found" if @offences.empty?}. " \
                   "Did you mean `#{@opposite_assertion}`?"
          end

          "expected offences to match#{", but there were none" if @offences.empty?}"
        end

        failure_message_when_negated do
          if source != expected
            return "Offence highlights have been given#{", but no offences found" if @offences.empty?}. " \
                   "Did you mean `#{@opposite_assertion}`?"
          end

          "expected no #{@type} offences"
        end
      end

      def expect_file_offence(expected_highlights, filepath)
        expect { |source| on_file(filepath, source) }.to cause_offence(expected_highlights)
          .type(:file).did_you_mean(:expect_no_file_offences)
      end

      def expect_no_file_offences(expected_highlights, filepath)
        expect { |source| on_file(filepath, source) }.not_to cause_offence(expected_highlights)
          .type(:file).did_you_mean(:expect_file_offence)
      end

      def expect_segment_offence(expected_highlights, lineno = nil, locale: nil)
        expect { |source| on_segment(source, lineno:, locale:) }.to cause_offence(expected_highlights)
          .type(:segment).did_you_mean(:expect_no_segment_offences)
      end

      def expect_no_segment_offences(expected_highlights, lineno = nil, locale: nil)
        expect { |source| on_segment(source, lineno:, locale:) }.not_to cause_offence(expected_highlights)
          .type(:segment).did_you_mean(:expect_segment_offence)
      end

      def expect_comparison_offence(expected_translation, expected_source, locale:, source_locale:)
        expect { |combined| on_comparison(*compare_split(combined), locale:, source_locale:) }
          .to cause_offence(compare_combine(expected_translation, expected_source))
          .type(:segment).did_you_mean(:expect_no_comparison_offences)
      end

      def expect_no_comparison_offences(expected_translation, expected_source, locale:, source_locale:)
        expect { |combined| on_comparison(*compare_split(combined), locale:, source_locale:) }
          .not_to cause_offence(compare_combine(expected_translation, expected_source))
          .type(:segment).did_you_mean(:expect_comparison_offence)
      end

      DUMMY_FILE = ::I18nLint::File.new(filepath: "<none>")

      JOINER = "\n---\n"

      private

      def compare_combine(translation, source) = [translation.chomp, source].join(JOINER)
      def compare_split(combined)              = combined.split(JOINER)

      def highlight_offences(content, offences)
        highlighted, unhighlighted = offences.partition(&:highlight)

        highlight_messages = highlighted.each_with_object({}) { |o, h| h[o.highlight] = o.message }

        actual = ::I18nLint::Highlighters::BelowLine.indicate(content, *highlight_messages.keys.flatten(1),
                                                              messages: highlight_messages.values)

        other = unhighlighted.filter_map(&:message).map(&:inspect).join("; ")
        actual.prepend "^ Offences without highlights: #{other}\n" unless other.empty?

        actual
      end

      def make_file(filepath, contents)
        file = Tempfile.create([filepath, ::File.extname(filepath)])
        file.tap { _1.write(contents) }.tap(&:rewind)
        ::I18nLint::Enumerator.new([file.path], source_locale: nil).each_file.first.tap { _1.filepath = filepath }
      end

      def on_file(filepath, contents)
        rule.on_file(make_file(filepath, contents))
        offences = rule.take_offences
        [highlight_offences(contents, offences), offences]
      end

      def make_segment(text, lineno: nil, locale: nil)
        ::I18nLint::Segment.new(text:, file: DUMMY_FILE, lineno:, locale:)
      end

      def on_segment(source, lineno: nil, locale: nil)
        rule.on_segment(make_segment(source, lineno:, locale:))
        offences = rule.take_offences
        [highlight_offences(source, offences), offences]
      end

      def on_comparison(translation, source, locale: nil, source_locale: nil)
        rule.on_segment_comparison make_segment(translation, locale:), make_segment(source, locale: source_locale)
        offences = rule.take_offences
        [
          compare_combine(
            highlight_offences(translation, offences),
            highlight_offences(source, offences.map(&:source_offence))
          ),
          offences
        ]
      end
    end
  end
end
