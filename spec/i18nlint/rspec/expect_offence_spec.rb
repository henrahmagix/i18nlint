# frozen_string_literal: true

RSpec.describe I18nLint::RSpec::ExpectOffence do
  def no_colour!
    allow(RSpec.configuration).to receive(:color_enabled?).and_return(false)
  end

  def allow_colour!
    allow(RSpec.configuration).to receive(:color_enabled?).and_return(true)
  end

  def fail_with(expected)
    no_colour!
    raise_error(RSpec::Expectations::ExpectationNotMetError) do |e|
      allow_colour!
      expect(e.message.chomp.gsub(/(\A\n)?Diff:\n+@@.*\n/, "Diff:\n")).to eq(expected.chomp)
    end
  end

  let(:rule) { Class.new(I18nLint::Rule).new }

  # Include the test call in the failure backtrace so it can be found just as if the `expect` call were written there.
  def self.test(description, rule_defs, *inputs, expected) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    test_locations = caller_locations(1, 2)
    it description do
      rule.class.class_eval(rule_defs)
      is_expected = assertion(*inputs)

      if expected == :passes
        is_expected.not_to raise_error
      else
        is_expected.to fail_with(expected)
      end
    rescue Exception => e # rubocop:disable Lint/RescueException
      e.set_backtrace (e.backtrace_locations + test_locations).uniq.map(&:to_s)
      raise e
    end
  end

  def self.passes(desc, defs, *inputs)          = test("passes #{desc}", defs, *inputs, :passes)
  def self.fails(desc, defs, *inputs, expected) = test("fails #{desc}", defs, *inputs, expected)

  describe "expect_file_offence" do
    def assertion(yaml) = expect { expect_file_offence(yaml, "file.yml") }

    passes "for a matching highlighted offence", <<~RUBY, <<~YAML
      def on_file(file) = add_offence(file, "gone wrong here", highlight: [[13, 16]])
    RUBY
      en:
        hello: Hello there
               ^^^ gone wrong here
    YAML

    passes "for a matching unhighlighted offence", <<~RUBY, <<~YAML
      def on_file(file) = add_offence(file, "gone wrong somewhere")
    RUBY
      ^ Offences without highlights: "gone wrong somewhere"
      en:
        hello: Hello there
    YAML

    fails "with a diff for multiple different highlighted offences", <<~RUBY, <<~YAML, <<~DIFF
      def on_file(file) = add_offence(file, "gone wrong here", highlight: [[14, 17], [19, 25]])
    RUBY
      en:
        hello: Hello there
               ^^^ gone wrong here
    YAML
      expected offences to match
      Diff:
       en:
         hello: Hello there
      -         ^^^ gone wrong here
      +          ^^^  ^^^^^ gone wrong here; gone wrong here
    DIFF

    fails "with a diff for a different unhighlighted offence", <<~RUBY, <<~YAML, <<~DIFF
      def on_file(file) = add_offence(file, "gone wrong somewhere")
    RUBY
      ^ blah blah
      en:
        hello: Hello there
    YAML
      expected offences to match
      Diff:
      -^ blah blah
      +^ Offences without highlights: "gone wrong somewhere"
       en:
         hello: Hello there
    DIFF

    fails "when there are no offences against highlighted input", <<~RUBY, <<~YAML, <<~DIFF
      def on_file(file) = nil
    RUBY
      en:
        hello: Hello there
               ^^^ gone wrong here
    YAML
      expected offences to match, but there were none
      Diff:
       en:
         hello: Hello there
      -         ^^^ gone wrong here
    DIFF

    fails "with a 'did you mean' for no offences against unhighlighted input", <<~RUBY, <<~YAML, <<~EXPECTED
      def on_file(file) = nil
    RUBY
      en:
        hello: Hello there
    YAML
      No offence highlights have been given, and none were found. Did you mean `expect_no_file_offences`?
    EXPECTED

    fails "with a diff and 'did you mean' for offences against unhighlighted input", <<~RUBY, <<~YAML, <<~EXPECTED
      def on_file(file)
        add_offence(file, "gone wrong somewhere")
        add_offence(file, "and again")
        add_offence(file, "gone wrong here", highlight: [[13, 25]])
      end
    RUBY
      en:
        hello: Hello there
    YAML
      No offence highlights have been given. Did you mean `expect_no_file_offences`?
      Diff:
      +^ Offences without highlights: "gone wrong somewhere"; "and again"
       en:
         hello: Hello there
      +         ^^^^^^^^^^^ gone wrong here
    EXPECTED
  end

  describe "expect_no_file_offences" do
    def assertion(yaml) = expect { expect_no_file_offences(yaml, "file.yml") }

    passes "when there are no offences against unhighlighted input", <<~RUBY, <<~YAML
      def on_file(file) = nil
    RUBY
      en:
        hello: Hello there
    YAML

    fails "with a diff when offences occur", <<~RUBY, <<~YAML, <<~DIFF
      def on_file(file)
        add_offence(file, "gone wrong somewhere")
        add_offence(file, "and again")
        add_offence(file, "gone wrong here", highlight: [[13, 25]])
      end
    RUBY
      en:
        hello: Hello there
    YAML
      expected no file offences
      Diff:
      +^ Offences without highlights: "gone wrong somewhere"; "and again"
       en:
         hello: Hello there
      +         ^^^^^^^^^^^ gone wrong here
    DIFF

    fails "with a 'did you mean' for matching offences", <<~RUBY, <<~YAML, <<~DIFF
      def on_file(file)
        add_offence(file, "all of this is unexpected")
        add_offence(file, "that is unexpected", highlight: [[13, 18]])
      end
    RUBY
      ^ Offences without highlights: "all of this is unexpected"
      en:
        hello: Hello there
               ^^^^^ that is unexpected
    YAML
      Offence highlights have been given. Did you mean `expect_file_offence`?
    DIFF

    fails "with a diff and 'did you mean' for no offences against highlighted input", <<~RUBY, <<~YAML, <<~DIFF
      def on_file(file) = nil
    RUBY
      en:
        hello: Hello there
               ^^^
    YAML
      Offence highlights have been given, but no offences found. Did you mean `expect_file_offence`?
      Diff:
       en:
         hello: Hello there
      -         ^^^
    DIFF
  end

  describe "expect_segment_offence" do
    def assertion(text) = expect { expect_segment_offence(text) }

    passes "for a matching highlighted offence", <<~RUBY, <<~TXT
      def on_segment(segment) = add_offence(segment, "gone wrong here", highlight: [[0, 3]])
    RUBY
      Hello there
      ^^^ gone wrong here
    TXT

    passes "for a matching unhighlighted offence", <<~RUBY, <<~TXT
      def on_segment(segment) = add_offence(segment, "gone wrong somewhere")
    RUBY
      ^ Offences without highlights: "gone wrong somewhere"
      Hello there
    TXT

    fails "with a diff for multiple different offences", <<~RUBY, <<~TXT, <<~DIFF
      def on_segment(segment)
        add_offence(segment, "gone wrong somewhere")
        add_offence(segment, "gone wrong here", highlight: [[1, 4], [6, 12]])
      end
    RUBY
      Hello there
      ^^^ gone wrong here
    TXT
      expected offences to match
      Diff:
      +^ Offences without highlights: "gone wrong somewhere"
       Hello there
      -^^^ gone wrong here
      + ^^^  ^^^^^ gone wrong here; gone wrong here
    DIFF

    fails "when there are no offences against highlighted input", <<~RUBY, <<~TXT, <<~DIFF
      def on_segment(segment) = nil
    RUBY
      Hello there
      ^^^ gone wrong here
    TXT
      expected offences to match, but there were none
      Diff:
       Hello there
      -^^^ gone wrong here
    DIFF

    fails "with a 'did you mean' for no offences against unhighlighted input", <<~RUBY, <<~TXT, <<~EXPECTED
      def on_segment(segment) = nil
    RUBY
      Hello there
    TXT
      No offence highlights have been given, and none were found. Did you mean `expect_no_segment_offences`?
    EXPECTED

    fails "with a diff and 'did you mean' for offences against unhighlighted input", <<~RUBY, <<~TXT, <<~EXPECTED
      def on_segment(segment)
        add_offence(segment, "gone wrong somewhere")
        add_offence(segment, "and again")
        add_offence(segment, "gone wrong here", highlight: [[0, 12]])
      end
    RUBY
      Hello there
    TXT
      No offence highlights have been given. Did you mean `expect_no_segment_offences`?
      Diff:
      +^ Offences without highlights: "gone wrong somewhere"; "and again"
       Hello there
      +^^^^^^^^^^^ gone wrong here
    EXPECTED
  end

  describe "expect_no_segment_offences" do
    def assertion(text) = expect { expect_no_segment_offences(text, "segment.yml") }

    passes "when there are no offences against unhighlighted input", <<~RUBY, <<~TXT
      def on_segment(segment) = nil
    RUBY
      Hello there
    TXT

    fails "with a diff when offences occur", <<~RUBY, <<~TXT, <<~DIFF
      def on_segment(segment)
        add_offence(segment, "gone wrong somewhere")
        add_offence(segment, "and again")
        add_offence(segment, "gone wrong here", highlight: [[0, 12]])
      end
    RUBY
      Hello there
    TXT
      expected no segment offences
      Diff:
      +^ Offences without highlights: "gone wrong somewhere"; "and again"
       Hello there
      +^^^^^^^^^^^ gone wrong here
    DIFF

    fails "with a 'did you mean' for matching offences", <<~RUBY, <<~TXT, <<~DIFF
      def on_segment(segment)
        add_offence(segment, "all of this is unexpected")
        add_offence(segment, "that is unexpected", highlight: [[0, 5]])
      end
    RUBY
      ^ Offences without highlights: "all of this is unexpected"
      Hello there
      ^^^^^ that is unexpected
    TXT
      Offence highlights have been given. Did you mean `expect_segment_offence`?
    DIFF

    fails "with a diff and 'did you mean' for no offences against highlighted input", <<~RUBY, <<~TXT, <<~DIFF
      def on_segment(segment) = nil
    RUBY
      Hello there
      ^^^
    TXT
      Offence highlights have been given, but no offences found. Did you mean `expect_segment_offence`?
      Diff:
       Hello there
      -^^^
    DIFF
  end

  describe "expect_comparison_offence" do
    def assertion(locale, translation, source_locale, source)
      expect { expect_comparison_offence(translation, source, locale:, source_locale:) }
    end

    passes "for a matching highlighted offence", <<~RUBY, :fr, <<~TXT, :en, <<~TXT
      def on_segment_comparison(segment, source)
        add_segment_compare_offence(segment, source, "gone wrong here", "is source", highlight: [[0, 3]], source_highlight: [[6, 9]])
      end
    RUBY
      Bonjour
      ^^^ gone wrong here
    TXT
      Hello there
            ^^^ is source
    TXT

    passes "for a matching unhighlighted offence", <<~RUBY, :fr, <<~TXT, :en, <<~TXT
      def on_segment_comparison(segment, source)
        add_segment_compare_offence(segment, source, nil, "gone wrong somewhere")
      end
    RUBY
      Bonjour
    TXT
      ^ Offences without highlights: "gone wrong somewhere"
      Hello there
    TXT

    passes "for multiple matching offences", <<~RUBY, :fr, <<~TXT, :en, <<~TXT
      def on_segment_comparison(segment, source)
        add_segment_compare_offence(segment, source, "gone wrong somewhere")
        add_segment_compare_offence(segment, source, nil, "source is here", source_highlight: [[1, 4], [6, 12]])
      end
    RUBY
      ^ Offences without highlights: "gone wrong somewhere"
      Bonjour tous les monde
    TXT
      Hello there
       ^^^  ^^^^^ source is here; source is here
    TXT

    fails "with a diff for multiple different offences", <<~RUBY, :fr, <<~TXT, :en, <<~TXT, <<~DIFF
      def on_segment_comparison(segment, source)
        add_segment_compare_offence(segment, source, "gone wrong somewhere")
        add_segment_compare_offence(segment, source, nil, "source is here", source_highlight: [[1, 4], [6, 12]])
      end
    RUBY
      Bonjour tous les monde
              ^ there is no offence for this
    TXT
      Hello there
      ^^^ gone wrong here
    TXT
      expected offences to match
      Diff:
      +^ Offences without highlights: "gone wrong somewhere"
       Bonjour tous les monde
      -        ^ there is no offence for this
       ---
       Hello there
      -^^^ gone wrong here
      + ^^^  ^^^^^ source is here; source is here
    DIFF

    fails "when there are no offences against highlighted input", <<~RUBY, :fr, <<~TXT, :en, <<~TXT, <<~DIFF
      def on_segment_comparison(segment, source) = nil
    RUBY
      Bonjour
      ^^^ gone wrong here
    TXT
      Hello there
    TXT
      expected offences to match, but there were none
      Diff:
       Bonjour
      -^^^ gone wrong here
       ---
       Hello there
    DIFF

    fails "with a 'did you mean' for no offences on no highlights", <<~RUBY, :fr, <<~TXT, :en, <<~TXT, <<~EXPECTED
      def on_segment_comparison(segment, source) = nil
    RUBY
      Hello there
    TXT
      Hello there
    TXT
      No offence highlights have been given, and none were found. Did you mean `expect_no_comparison_offences`?
    EXPECTED

    fails "with a diff and 'did you mean' for offences on no highlights", <<~RUBY, :fr, <<~TXT, :en, <<~TXT, <<~EXPECTED
      def on_segment_comparison(segment, source)
        add_segment_compare_offence(segment, source, "gone wrong somewhere")
        add_segment_compare_offence(segment, source, "and again")
        add_segment_compare_offence(segment, source, nil, "gone wrong here", source_highlight: [[0, 12]])
      end
    RUBY
      Bonjour
    TXT
      Hello there
    TXT
      No offence highlights have been given. Did you mean `expect_no_comparison_offences`?
      Diff:
      +^ Offences without highlights: "gone wrong somewhere"; "and again"
       Bonjour
       ---
       Hello there
      +^^^^^^^^^^^ gone wrong here
    EXPECTED
  end

  describe "expect_no_comparison_offences" do
    def assertion(locale, translation, source_locale, source)
      expect { expect_no_comparison_offences(translation, source, locale:, source_locale:) }
    end

    passes "when there are no offences against unhighlighted input", <<~RUBY, :fr, <<~TXT, :en, <<~TXT
      def on_segment_comparison(segment, source) = nil
    RUBY
      Hello there
    TXT
      Hello there
    TXT

    fails "with a diff when offences occur", <<~RUBY, :fr, <<~TXT, :en, <<~TXT, <<~DIFF
      def on_segment_comparison(segment, source)
        add_segment_compare_offence(segment, source, "gone wrong somewhere")
        add_segment_compare_offence(segment, source, nil, "and in the source")
        add_segment_compare_offence(segment, source, "gone wrong here", "source is here", highlight: [[0, 1]], source_highlight: [[0, 12]])
      end
    RUBY
      Bonjour
    TXT
      Hello there
    TXT
      expected no segment offences
      Diff:
      +^ Offences without highlights: "gone wrong somewhere"
       Bonjour
      +^ gone wrong here
       ---
      +^ Offences without highlights: "and in the source"
       Hello there
      +^^^^^^^^^^^ source is here
    DIFF

    fails "with a 'did you mean' for matching offences", <<~RUBY, :fr, <<~TXT, :en, <<~TXT, <<~DIFF
      def on_segment_comparison(segment, source)
        add_segment_compare_offence(segment, source, nil, "all of this is unexpected")
        add_segment_compare_offence(segment, source, "that is unexpected", highlight: [[0, 5]])
      end
    RUBY
      Bonjour
      ^^^^^ that is unexpected
    TXT
      ^ Offences without highlights: "all of this is unexpected"
      Hello there
    TXT
      Offence highlights have been given. Did you mean `expect_comparison_offence`?
    DIFF

    fails "with a diff and 'did you mean' for no offences on highlights", <<~RUBY, :fr, <<~TXT, :en, <<~TXT, <<~DIFF
      def on_segment_comparison(segment, source) = nil
    RUBY
      Bonjour
      ^^^
    TXT
      Hello there
      ^^^
    TXT
      Offence highlights have been given, but no offences found. Did you mean `expect_comparison_offence`?
      Diff:
       Bonjour
      -^^^
       ---
       Hello there
      -^^^
    DIFF
  end
end
