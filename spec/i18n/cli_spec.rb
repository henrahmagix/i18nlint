# frozen_string_literal: true

require "i18n/lint/cli"

RSpec.describe I18n::Lint::CLI do
  it "prints the offences and exits 0" do
    stub_const "::ARGV", ["--source=en", "--config=spec/examples/cli/config.yml", "spec/examples/cli/locales/*.yml"]
    expect { described_class.run }
      .to raise_error(SystemExit) { _1.status == 1 }
      .and output(<<~OUT).to_stdout
        Inspecting 3 files
        ...

        Offences:

        spec/examples/cli/locales/comments.yml:4: MyScope::NoComments
          # This is not allowed.
          # It is a block comment that is not allowed.

        spec/examples/cli/locales/comments.yml:7: MyScope::NoComments
          # This single line is not allowed.

        2 offences detected
      OUT
  end
end
