# frozen_string_literal: true

RSpec.describe I18nLint do
  it "has a version number" do
    expect(I18nLint::VERSION).not_to be nil
  end

  it "passes through to the Linter" do
    filepaths = ["one.yml", "two.rb"]
    source_locale = "pl"

    offences = ["mock", "the real values will not be strings, but this test is a unit test, so we're mocking simply"]

    linter = instance_double(I18nLint::Linter)
    expect(I18nLint::Linter).to receive(:new).with(filepaths:, source_locale:).and_return(linter)
    expect(linter).to receive_messages(
      run: nil,
      run_comparison: nil,
      offences:
    )

    expect(described_class.lint(filepaths, source_locale:)).to be(offences)
  end

  it "finds offences for a registered rule" do
    stub_const("::Test::OnlyOneTopLevelKey", Class.new(I18nLint::Rule) do
      def self.description = "Each file should only have 1 top-level locale key."

      def on_file(i18n_file)
        top_level_keys = i18n_file.parsed.keys
        return if top_level_keys.size < 2

        add_offence(i18n_file, "too many top-level keys: #{top_level_keys.join(", ")}")
      end
    end)

    I18nLint.register_rule(Test::OnlyOneTopLevelKey)

    good = temp_file "good.yml", "en: {}"
    bad = temp_file "bad.yml", "fr: {}\nen: {}"

    expect(I18nLint.lint([good, bad], source_locale: "fr")).to eq [
      I18nLint::FileOffence.new(rule: "Test/OnlyOneTopLevelKey Each file should only have 1 top-level locale key.",
                                filepath: bad.to_s, message: "too many top-level keys: fr, en")
    ]
  end
end
