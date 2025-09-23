# frozen_string_literal: true

require "i18n/lint/cli"

RSpec.describe I18n::Lint::CLI do
  let(:ignore_will_never_run_classes) do
    %w[
      TestClassRule
    ]
  end

  before do
    allow(I18n::Lint::Registry).to receive(:register_rule).and_wrap_original do |m, *args, **kwargs, &block|
      if args[0].name.to_s.empty? || ignore_will_never_run_classes.include?(args[0].name)
        warn "Ignoring rule from other tests: #{args[0]}"
      else
        m.call(*args, **kwargs, &block)
      end
    end
  end

  it "prints the offences and exits 0" do
    stub_const "::ARGV", ["--source=en", "--config=spec/examples/cli/config.yml", "spec/examples/cli/locales/*.yml"]
    expect { described_class.run }
      .to raise_error(SystemExit) { _1.status == 1 }
      .and output(<<~OUT).to_stdout
        Inspecting 3 files
        ...

        Offences:

        spec/examples/cli/locales/comments.yml:4: MyScope/NoComments with AllowedPatterns: /^NOTE: /
          # This is not allowed.
          # It is a block comment that is not allowed.

        spec/examples/cli/locales/comments.yml:7: MyScope/NoComments with AllowedPatterns: /^NOTE: /
          # This single line is not allowed.

        spec/examples/cli/locales/fr.yml:5: BuiltIn/MatchFile /German/i
            i_am_a_g

        spec/examples/cli/locales/en.yml:4 in en.causes_offence: BuiltIn/MatchSegment /wef/
          This has wef in it!

        4 offences detected
      OUT
  end
end
