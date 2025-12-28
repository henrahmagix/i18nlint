# frozen_string_literal: true

require "i18nlint/cli"

RSpec.describe I18nLint::CLI do
  around do |example|
    example.run
  rescue SystemExit
    raise "Exited non-zero. You should assert `system_exit(n)` so you can assert on the output without RSpec quitting."
  end

  def match_on_one_line(*parts)
    include(/#{parts.map { Regexp.escape(_1) }.join(".*")}/)
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
    expect { described_class.run([]) }
      .to system_exit(1)
      .and print_help
  end

  it "fails when --config does not exist" do
    expect { described_class.run(["--source", "FR", "--config", "unknown/config.yml"]) }
      .to system_exit(1)
      .and print_help(with: "Config file does not exist: unknown/config.yml")
  end

  it "exits 0 when no files are given" do
    expect { described_class.run(["--source", "FR"]) }
      .to system_exit(0)
      .and output("No files given\n").to_stdout
  end

  it "exits 0 when no rules are defined" do
    allow(I18nLint::Rule).to receive(:rule_classes).and_return []
    allow(I18nLint::Registry).to receive(:rules).and_return []
    expect { described_class.run(["--source=fr", "spec/examples/**/*.yml"]) }
      .to system_exit(0)
      .and output("No rules configured\n").to_stdout
      .and output(anything).to_stderr # suppress
  end

  context "with spec/example rules allowed" do
    ignore_test_rules except: "**/spec/examples/**/*"

    let(:args) { ["--source", source, "--config=spec/examples/cli/config.yml", *Array(files)] }

    context "without any offending I18n" do
      let(:source) { "pl" }
      let(:files) { "spec/examples/cli/locales/good.yml" }

      it "exits 0 without any offences" do
        expect { described_class.run(args) }
          .to system_exit(0)
          .and output(anything).to_stderr # suppress
          .and output(<<~OUT).to_stdout
            Inspecting 1 files
            .
            Comparing segments to source PL


            No offences detected
          OUT
      end
    end

    context "with offending I18n" do
      let(:source) { "en" }
      let(:files) { "spec/examples/cli/locales/*" }

      it "prints the offences and exits 0" do
        expect { described_class.run(args) }
          .to system_exit(1)
          .and output(anything).to_stderr # suppress for this test
          .and output(<<~OUT).to_stdout
            Inspecting 10 files
            FF.F.F..F.
            Comparing segments to source EN
            ...FF

            Offences:

            spec/examples/cli/locales/comments.rb:6: MyScope/NoComments with AllowedPatterns: /^NOTE: /
              # This single Ruby comment is not allowed.

            spec/examples/cli/locales/comments.yml:4: MyScope/NoComments with AllowedPatterns: /^NOTE: /
              # This is not allowed.
              # It is a block comment that is not allowed.

            spec/examples/cli/locales/comments.yml:7: MyScope/NoComments with AllowedPatterns: /^NOTE: /
              # This single line is not allowed.

            spec/examples/cli/locales/en.yml:4 in en.causes_offence: match-segment /wef/
              This has wef in it!
                       ^^^

            spec/examples/cli/locales/fr.yml:5: match-file /German/i
                i_am_a_german_key: 'Was gehn der alter?'
                       ^^^^^^

            spec/examples/cli/locales/interpolations.yml:4 in fr.welcome: BuiltIn/Interpolations: broken
              Bienvenue % {name}
                        ^^^^^^^^

            Comparison: BuiltIn/Interpolations
            spec/examples/cli/locales/interpolations.yml:4 in fr.welcome
              Bienvenue % {name}
            spec/examples/cli/locales/interpolations.yml:2 in en.welcome: missing in fr: name
              Welcome %{name}
                      ^^^^^^^

            Comparison: mismatch-to-source /\\[[A-Z_]+\\]/
            spec/examples/cli/locales/raise_brackets_comparison.rb: in fr.brackets2: Found mismatches to the source EN
              et ca c'est [VOTRE_TAG]
                          ^^^^^^^^^^^
              pour [YOUR_NAME]
            spec/examples/cli/locales/raise_brackets_comparison.rb: in en.brackets2
              and that is [YOUR_TAG]
                          ^^^^^^^^^^
              for [YOUR_NAME]

            8 offences detected
          OUT
      end

      it "warns about unused rules and configuration, and any unhandled I18nLint::Errors that occur" do
        expect do
          described_class.run(args)
        rescue SystemExit
          nil
        end
        .to output(anything).to_stdout
        .and output(<<~ERR).to_stderr # should exclude MissingName + MissingRuleKey; we assert on the whole output here
          Rule BadImplementation will not be used: it must respond to at least one of :on_file, :on_segment, :on_segment_comparison
          uh oh, i cannot initialize
          Unused configuration "ThisWillNotBe/Used" expects class ThisWillNotBe::Used to subclass I18nLint::Rule. If this is a rule you're expecting to be used, that means it hasn't been loaded in the `require:` list, or it doesn't subclass I18nLint::Rule.
          This is an evaluated Ruby file. The final value should be the hash of I18n.
        ERR
      end
    end
  end
end
