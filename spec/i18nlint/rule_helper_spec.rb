# frozen_string_literal: true

RSpec.describe I18nLint::RuleHelper do
  let(:helper) { Class.new.tap { _1.include described_class }.new }

  describe "xor!" do
    it "mutates the given arrays by == comparison, not normalising duplicates i.e. not using `uniq`" do
      a = [1, 1, 2, 1, 3]
      b = [1, 2, 3, 4]
      helper.xor!(a, b)
      expect([a, b]).to eq [[1, 1], [4]]
    end

    it "returns the elements that are removed" do
      a = [1, 1, 2, 1, 3]
      b = [1, 2, 3, 4]
      expect(helper.xor!(a, b)).to eq [[1, 2, 3], [1, 2, 3]]
    end

    it "can be given a method proc to apply to each input for comparison" do
      a = [1, 1, 2, 1, 3]
      b = [5, 5, 5]
      helper.xor!(a, b, &:odd?)
      expect([a, b]).to eq [[2, 3], []]
    end

    it "can be given a comparison block" do
      a = [10, 15, 20]
      b = [[5, true], [5, false], [5, true]]
      helper.xor!(a, b) { |a, b| b[1] && a % b[0] == 0 }
      expect([a, b]).to eq [[20], [[5, false]]]
    end
  end

  describe "def_segment_comparison" do
    let(:rule) { Class.new(I18nLint::Rule).tap { _1.include(described_class) }.new }

    before do
      rule.class.def_segment_comparison(
        includes_highlights:,
        message: (message if defined? message),
        source_message: (source_message if defined? source_message),
        &process_segment
      )
    end

    context "with a proc that just pulls values from the segment" do
      let(:includes_highlights) { false }
      let(:process_segment) { ->(segment) { segment.text.scan("|") } }

      it "does not record an offence when both segments are processed identically" do
        expect_no_comparison_offences <<~SEGMENT, <<~SOURCE, locale: "fr", source_locale: "en"
          le premiere | le deuxieme
        SEGMENT
          the first | the second
        SOURCE
      end

      it "records an offence when the translation has extra over the source" do
        expect_comparison_offence <<~SEGMENT, <<~SOURCE, locale: "fr", source_locale: "en"
          le premiere | le deuxieme
        SEGMENT
          the first - the second
        SOURCE
      end

      it "records an offence when the translation is missing stuff from the source" do
        expect_comparison_offence <<~SEGMENT, <<~SOURCE, locale: "fr", source_locale: "en"
          le premiere - le deuxieme
        SEGMENT
          the first | the second
        SOURCE
      end

      context "and string messages" do
        let(:message) { "translation should match source" }
        let(:source_message) { "this is what the translation should look like, but translated" }

        it "records an offence when the translation has extra over the source" do
          expect_comparison_offence <<~SEGMENT, <<~SOURCE, locale: "fr", source_locale: "en"
            ^ Offences without highlights: "translation should match source"
            le premiere | le deuxieme
          SEGMENT
            ^ Offences without highlights: "this is what the translation should look like, but translated"
            the first - the second
          SOURCE
        end

        it "records an offence when the translation is missing stuff from the source" do
          expect_comparison_offence <<~SEGMENT, <<~SOURCE, locale: "fr", source_locale: "en"
            ^ Offences without highlights: "translation should match source"
            le premiere - le deuxieme
          SEGMENT
            ^ Offences without highlights: "this is what the translation should look like, but translated"
            the first | the second
          SOURCE
        end
      end

      context "and proc messages" do
        let(:message) do
          lambda do |matches, segment, source|
            next if matches.empty?

            "matches found in translation #{segment.locale} compared to source #{source.locale}: #{matches.join("; ")}"
          end
        end
        let(:source_message) do
          lambda do |matches, segment, source|
            next if matches.empty?

            "matches found in source #{source.locale} compared to translation #{segment.locale}: #{matches.join("; ")}"
          end
        end

        it "does not record an offence when both segments are processed identically" do
          expect_no_comparison_offences <<~SEGMENT, <<~SOURCE, locale: "fr", source_locale: "en"
            le premiere | le deuxieme
          SEGMENT
            the first | the second
          SOURCE
        end

        it "calls each message proc with the matches when translation has extra over the source" do
          expect_comparison_offence <<~SEGMENT, <<~SOURCE, locale: "fr", source_locale: "en"
            ^ Offences without highlights: "matches found in translation fr compared to source en: |"
            le premiere | le deuxieme
          SEGMENT
            the first - the second
          SOURCE
        end

        it "calls each message proc with the matches when source has extra over the translation" do
          expect_comparison_offence <<~SEGMENT, <<~SOURCE, locale: "fr", source_locale: "en"
            le premiere - le deuxieme
          SEGMENT
            ^ Offences without highlights: "matches found in source en compared to translation fr: |"
            the first | the second
          SOURCE
        end
      end
    end

    context "with a proc that just values and highlights from the segment" do
      let(:includes_highlights) { true }
      let(:process_segment) do
        lambda { |segment|
          segment.text.enum_for(:scan, "|").map do |match|
            [match, Regexp.last_match.offset(0)]
          end
        }
      end

      it "does not record an offence when both segments are processed identically" do
        expect_no_comparison_offences <<~SEGMENT, <<~SOURCE, locale: "fr", source_locale: "en"
          le premiere | le deuxieme
        SEGMENT
          the first | the second
        SOURCE
      end

      it "records an offence with highlight indications when the translation has extra over the source" do
        expect_comparison_offence <<~SEGMENT, <<~SOURCE, locale: "fr", source_locale: "en"
          le premiere | le deuxieme
                      ^ <nil>
        SEGMENT
          the first - the second
        SOURCE
      end

      it "records an offence with highlight indications when the translation is missing stuff from the source" do
        expect_comparison_offence <<~SEGMENT, <<~SOURCE, locale: "fr", source_locale: "en"
          le premiere - le deuxieme
        SEGMENT
          the first | the second
                    ^ <nil>
        SOURCE
      end

      context "and string messages" do
        let(:message) { "translation should match source" }
        let(:source_message) { "this is what the translation should look like, but translated" }

        it "does not record an offence when both segments are processed identically" do
          expect_no_comparison_offences <<~SEGMENT, <<~SOURCE, locale: "fr", source_locale: "en"
            le premiere | le deuxieme
          SEGMENT
            the first | the second
          SOURCE
        end

        it "passes along the messages to the offence record" do
          expect_comparison_offence <<~SEGMENT, <<~SOURCE, locale: "fr", source_locale: "en"
            le premiere | le deuxieme
                        ^ translation should match source
          SEGMENT
            ^ Offences without highlights: "this is what the translation should look like, but translated"
            the first - the second
          SOURCE
        end
      end

      context "and proc messages" do
        let(:message) do
          lambda do |matches, segment, source|
            next if matches.empty?

            "matches found in translation #{segment.locale} compared to source #{source.locale}: #{matches.join("; ")}"
          end
        end
        let(:source_message) do
          lambda do |matches, segment, source|
            next if matches.empty?

            "matches found in source #{source.locale} compared to translation #{segment.locale}: #{matches.join("; ")}"
          end
        end

        it "does not record an offence when both segments are processed identically" do
          expect_no_comparison_offences <<~SEGMENT, <<~SOURCE, locale: "fr", source_locale: "en"
            le premiere | le deuxieme
          SEGMENT
            the first | the second
          SOURCE
        end

        it "calls each message proc with the matches when translation has extra over the source" do
          expect_comparison_offence <<~SEGMENT, <<~SOURCE, locale: "fr", source_locale: "en"
            le premiere | le deuxieme
                        ^ matches found in translation fr compared to source en: |
          SEGMENT
            the first - the second
          SOURCE
        end

        it "calls each message proc with the matches when source has extra over the translation" do
          expect_comparison_offence <<~SEGMENT, <<~SOURCE, locale: "fr", source_locale: "en"
            le premiere - le deuxieme
          SEGMENT
            the first | the second
                      ^ matches found in source en compared to translation fr: |
          SOURCE
        end
      end
    end
  end
end
