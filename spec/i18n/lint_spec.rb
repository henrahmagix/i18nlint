# frozen_string_literal: true

RSpec.describe I18n::Lint do
  it "has a version number" do
    expect(I18n::Lint::VERSION).not_to be nil
  end

  it "allows registering rules" do
    expect(I18n::Lint.register_rule(/match me/)).to be_a(I18n::Lint::RuleType)
  end

  it "allows registering rule types" do
    test_rule_type_class = Class.new(I18n::Lint::RuleType)
    test_rule_type_class.const_set :TYPE, Array
    expect(I18n::Lint.register_rule_type(test_rule_type_class)).to be(test_rule_type_class)
  end

  it "lints the given files" do
    expect(I18n::Lint.lint("examples/*.yml", source_locale: "en")).to be(true)
  end
end
