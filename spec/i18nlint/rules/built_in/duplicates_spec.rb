# frozen_string_literal: true

# This needs to be an integration test that goes through reading/parsing/loading the I18n from YAML files, to ensure
# this rule finds duplicates even when the I18n store in memory won't have duplicates (because hash merges always keep
# the last value set for any given key).
File.write "spec/examples/duplicates/uniq_within_locale_en.yml", <<~YML
  en:
    a:
      b:
        c: "" # content doesn't matter
    d:
      e:
        f: ""
YML
File.write "spec/examples/duplicates/uniq_within_locale_fr.yml", <<~YML
  fr:
    a:
      b:
        c: "" # ce pas attention
    d:
      e:
        f: ""
YML
File.write "spec/examples/duplicates/duplicate_within_locale1_en.yml", <<~YML
  en:
    a:
      b:
        c: ""
        x: ""
YML
File.write "spec/examples/duplicates/duplicate_within_locale2_en.yml", <<~YML
  en:
    a:
      b:
        c: ""
        y: ""
YML
File.write "spec/examples/duplicates/duplicate_within_locale3_en.yml", <<~YML
  en:
    a:
      b:
        c: ""
        z: ""
YML
File.write "spec/examples/duplicates/duplicate_same_file_en.yml", <<~YML
  en:
    a:
      b:
        c: "first"
        first: "yes"
    d: "last"
    a:
      b:
        c: "second"
        second: "yes"
YML

RSpec.describe I18nLint::Rules::BuiltIn::Duplicates do
  attr_reader :linter

  def run(glob)
    I18nLint::Registry.register_rule(described_class)
    @linter = I18nLint::Linter.new(filepaths: glob, source_locale: "en")
    @linter.run
    @linter.run_comparison
    @linter.offences
  end

  it "reports no offences for unique keys within locales" do
    expect(run("spec/examples/duplicates/uniq_within_locale_*.yml")).to be_empty
  end

  it "reports offence for duplicate keys within locales; the first occurrence is never skipped", :aggregate_failures do
    offences = run("spec/examples/duplicates/duplicate_within_locale*_*.yml").sort_by(&:filepath)
    expect(offences[0]).to have_attributes(rule: "BuiltIn/Duplicates", key: "a.b.c",
                                           filepath: "spec/examples/duplicates/duplicate_within_locale1_en.yml")
    expect(offences[1]).to have_attributes(rule: "BuiltIn/Duplicates", key: "a.b.c",
                                           filepath: "spec/examples/duplicates/duplicate_within_locale2_en.yml")
    expect(offences[2]).to have_attributes(rule: "BuiltIn/Duplicates", key: "a.b.c",
                                           filepath: "spec/examples/duplicates/duplicate_within_locale3_en.yml")

    # TODO: move this test elsewhere, so we can understand how hash merges override keys or not. Our enumerator goes per
    # file so won't override, but I18n merges everything into one store so it will be overriding, I believe.
    expect(linter.send(:enum).each_segment.map { [_1.key, _1.text] }).to contain_exactly(
      ["a.b.c", ""],
      ["a.b.c", ""],
      ["a.b.c", ""],
      ["a.b.x", ""],
      ["a.b.y", ""],
      ["a.b.z", ""]
    )
  end

  it "reports offence for duplicate keys in the same file that YAML parsing overwrites", :aggregate_failures do
    offences = run("spec/examples/duplicates/duplicate_same_file_en.yml").sort_by(&:key)
    expect(offences[0]).to have_attributes(
      rule: "BuiltIn/Duplicates", lineno: 2, message: "will be overwritten by value at line 7 column 4",
      highlight: [6, 8], text: "a:",
      filepath: "spec/examples/duplicates/duplicate_same_file_en.yml"
    )
    expect(offences[1]).to have_attributes(
      rule: "BuiltIn/Duplicates", lineno: 3, message: "will be overwritten by value at line 8 column 6",
      highlight: [13, 15], text: "b:",
      filepath: "spec/examples/duplicates/duplicate_same_file_en.yml"
    )
    expect(offences[2]).to have_attributes(
      rule: "BuiltIn/Duplicates", lineno: 4, message: "will be overwritten by value at line 9 column 8",
      highlight: [22, 24], text: "c:",
      filepath: "spec/examples/duplicates/duplicate_same_file_en.yml"
    )
    expect(offences.length).to be(3)
  end
end
