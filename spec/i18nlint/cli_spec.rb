# frozen_string_literal: true

require "i18nlint/cli"

module DisableTestSubclassesToAvoidTestPolution
  def inherited(base)
    super
    base.inherited_location = caller_locations(1, 1)[0].absolute_path
  end

  attr_accessor :inherited_location

  def test_class?
    return false if inherited_location.nil? || inherited_location.include?("/spec/examples/")

    inherited_location.match?(%r{^#{File.expand_path("..", __dir__)}/.*_spec\.rb$})
  end
end
I18nLint::Rule.singleton_class.prepend DisableTestSubclassesToAvoidTestPolution

RSpec.describe I18nLint::CLI do
  before do
    allow(I18nLint::Rule).to receive(:subclasses).and_wrap_original do |m, *a, **kw, &b|
      m.call(*a, **kw, &b).reject do |subclass|
        subclass.test_class?.tap do |rejected|
          warn "Ignoring rule from other tests: #{subclass.name || "<no name>"}/#{subclass.inspect}" if rejected
        end
      end
    end
  end

  def match_on_one_line(*parts)
    include(/#{parts.join(".*")}/)
  end

  def system_exit(expected_status)
    raise_error(SystemExit) { |e| expect(e.status).to be(expected_status) }
  end

  it "prints the offences and exits 0" do
    stub_const "::ARGV", ["--source=en", "--config=spec/examples/cli/config.yml", "spec/examples/cli/locales/*.yml"]
    expect { described_class.run }
      .to system_exit(1)
      .and output(
        match_on_one_line(
          'Unused configuration "ThisWillNotBe/Used" expects class ThisWillNotBe::Used',
          "hasn't been loaded",
          "doesn't subclass I18nLint::Rule"
        )
      ).to_stderr
      .and output(<<~OUT).to_stdout
        Inspecting 7 files
        F.F.F..
        Comparing segments to source en
        ...F

        Offences:

        spec/examples/cli/locales/comments.yml:4: MyScope/NoComments with AllowedPatterns: /^NOTE: /
          # This is not allowed.
          # It is a block comment that is not allowed.

        spec/examples/cli/locales/comments.yml:7: MyScope/NoComments with AllowedPatterns: /^NOTE: /
          # This single line is not allowed.

        spec/examples/cli/locales/en.yml:4 in en.causes_offence: BuiltIn/MatchSegment /wef/
          This has wef in it!

        spec/examples/cli/locales/fr.yml:5: BuiltIn/MatchFile /German/i
            i_am_a_german_key: 'Was gehn der alter?'

        spec/examples/cli/locales/raise_brackets_comparison.yml:4 in fr.brackets2: BuiltIn/MatchSegmentToSource /\\[[A-Z_]+\\]/ - [YOUR_TAG] found 0 times, but should be 1
          et ca c'est your tag
        spec/examples/cli/locales/raise_brackets_comparison.yml:2 in en.brackets2:
          and that is [YOUR_TAG]

        5 offences detected
      OUT
  end
end
