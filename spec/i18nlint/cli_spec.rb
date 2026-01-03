# frozen_string_literal: true

require "i18nlint/cli"

RSpec.describe I18nLint::CLI do
  around do |example|
    example.run
  rescue SystemExit
    raise "Exited non-zero. You should assert `system_exit(n)` so you can assert on the output without RSpec quitting."
  end

  def system_exit(expected_status)
    raise_error(SystemExit) { |e| expect(e.status).to be(expected_status) }
  end

  def print_help(with: nil)
    expected = I18nLint::Configuration.help
    expected = "#{with}\n#{expected}" if with
    output(expected).to_stderr
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
      .and print_help(with: "No files given")
  end

  it "exits 0 when no rules are defined, which won't happen whilst we're always enabling some builtins" do
    allow(I18nLint::Rule).to receive(:rule_classes).and_return []
    allow(I18nLint::Registry).to receive(:rules).and_return []
    expect { described_class.run(["--source=fr", *random_files]) }
      .to system_exit(0)
      .and print_help(with: "No rules configured")
  end

  context "without any offending I18n" do
    let(:args) { ["--source", "pl", "--config=#{config_filepath}", locale_filepath] }
    let(:config_filepath) { temp_file("empty.yml", "") }
    let(:locale_filepath) do
      temp_file "good.yml", <<~YAML
        en:
          ok: This should not match any test rules
        pl:
          ok: Dobrze
      YAML
    end

    it "exits 0 without any offences or errors" do
      expect { described_class.run(args) }
        .to system_exit(0)
        .and output("").to_stderr
        .and output(<<~OUT).to_stdout
          Inspecting 1 files
          .
          Comparing segments to source PL
          .

          No offences detected
        OUT
    end
  end

  context "with offending I18n and a large config using all builtins" do
    let(:args) { ["--source", "en", "--config=spec/examples/cli/config.yml", "spec/examples/cli/locales/*"] }

    it "warns about unused rules and configuration errors, prints the offences, and exits 0" do
      expect { described_class.run(args) }
        .to system_exit(1)
        .and(output(<<~ERR).to_stderr)
          Rule BadImplementation will not be used: it must respond to at least one of :on_file, :on_segment, :on_segment_comparison
          uh oh, i cannot initialize
          Unused configuration "ThisWillNotBe/Used" expects class ThisWillNotBe::Used to subclass I18nLint::Rule. If this is a rule you're expecting to be used, that means it hasn't been loaded in the `require:` list, or it doesn't subclass I18nLint::Rule.
          This is an evaluated Ruby file. The final value should be the hash of I18n.
        ERR
        .and(output(<<~OUT).to_stdout)
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
  end
end
