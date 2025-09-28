# frozen_string_literal: true

require "i18nlint/cli"

module DisableTestSubclassesToAvoidTestPolution
  def inherited(base)
    super
    base.inherited_location = caller_locations(1, 1)[0].absolute_path
  end

  attr_accessor :inherited_location

  def test_class?(allow_examples_directory:)
    return false if inherited_location.nil?
    return false if allow_examples_directory && inherited_location.include?("/spec/examples/")

    inherited_location.start_with?(File.expand_path("..", __dir__))
  end
end
I18nLint::Rule.singleton_class.prepend DisableTestSubclassesToAvoidTestPolution

RSpec.describe I18nLint::CLI do
  let(:allow_examples_directory) { false }

  before do
    stderr_uncaptured = $stderr
    allow(I18nLint::Rule).to receive(:subclasses).and_wrap_original do |m, *a, **kw, &b|
      m.call(*a, **kw, &b).reject do |subclass|
        if subclass.test_class?(allow_examples_directory:)
          stderr_uncaptured.puts "Ignoring rule #{subclass.name || subclass.inspect} at #{subclass.inherited_location}"
          true
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

  def print_help(with: nil)
    match = include("Usage: i18nlint files...")
    match = match.and(include(with)) if with
    output(match).to_stderr
  end

  it "fails without a --source" do
    stub_const "::ARGV", []
    expect { described_class.run }
      .to system_exit(1)
      .and print_help
  end

  it "fails when --config does not exist" do
    stub_const "::ARGV", ["--source", "FR", "--config", "unknown/config.yml"]
    expect { described_class.run }
      .to system_exit(1)
      .and print_help(with: "Config file does not exist: unknown/config.yml")
  end

  it "exits 0 when no files are given" do
    stub_const "::ARGV", ["--source", "FR"]
    expect { described_class.run }
      .to system_exit(0)
      .and output("No files given or rules configured\n").to_stdout
  end

  it "exits 0 when no rules are defined" do
    stub_const "::ARGV", ["--source=fr", "spec/examples/**/*.yml"]
    expect { described_class.run }
      .to system_exit(0)
      .and output("No files given or rules configured\n").to_stdout
  end

  context "with spec/example rules allowed" do
    let(:allow_examples_directory) { true }

    it "exits 0 without any offences" do
      stub_const "ARGV", ["--source=pl", "--config=spec/examples/cli/config.yml", "spec/examples/cli/locales/good.yml"]
      expect { described_class.run }
        .to system_exit(0)
        .and output(<<~OUT).to_stdout
          Inspecting 1 files
          .
          Comparing segments to source PL


          No offences detected
        OUT
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
          Inspecting 8 files
          F.F.F...
          Comparing segments to source EN
          ...F

          Offences:

          spec/examples/cli/locales/comments.yml:4: MyScope/NoComments with AllowedPatterns: /^NOTE: /
            # This is not allowed.
            # It is a block comment that is not allowed.

          spec/examples/cli/locales/comments.yml:7: MyScope/NoComments with AllowedPatterns: /^NOTE: /
            # This single line is not allowed.

          spec/examples/cli/locales/en.yml:4 in en.causes_offence: BuiltIn/MatchSegment /wef/
            This has wef in it!
                     ^^^

          spec/examples/cli/locales/fr.yml:5: BuiltIn/MatchFile /German/i
              i_am_a_german_key: 'Was gehn der alter?'
                     ^^^^^^

          spec/examples/cli/locales/raise_brackets_comparison.yml:4 in fr.brackets2: BuiltIn/MatchSegmentToSource /\\[[A-Z_]+\\]/ - [YOUR_TAG] found 0 times, but should be 1
            et ca c'est your tag
          spec/examples/cli/locales/raise_brackets_comparison.yml:2 in en.brackets2:
            and that is [YOUR_TAG]
                        ^^^^^^^^^^

          5 offences detected
        OUT
    end
  end
end
