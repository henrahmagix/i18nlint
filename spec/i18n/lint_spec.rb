# frozen_string_literal: true

RSpec.describe I18nLint do
  it "has a version number" do
    expect(I18nLint::VERSION).not_to be nil
  end

  it "allows registering rules" do
    test_rule_class = Class.new(I18nLint::Rule) do
      def on_segment(*); end
    end
    expect(I18nLint.register_rule(test_rule_class)).to be_a(I18nLint::RuleType)
  end

  it "allows registering rule types" do
    test_rule_type_class = Class.new(I18nLint::RuleType)
    test_rule_type_class.const_set :TYPE, Array
    expect(I18nLint.register_rule_type(test_rule_type_class)).to be(test_rule_type_class)
  end

  context "with a class rule with a description" do
    let(:klass) do
      Class.new(I18nLint::Rule) do
        def self.description = "Each file should only have 1 top-level locale key."

        def self.name = "Test::Description"

        def on_file(i18n_file)
          top_level_keys = i18n_file.parsed.flat_map(&:keys)
          return if top_level_keys.size < 2

          add_offence(i18n_file)
        end
      end
    end

    before { I18nLint.register_rule(klass) }

    it "finds offences for the rule" do
      examples = Pathname.new(File.expand_path("../examples/", __dir__))
      expect(I18nLint.lint(examples.join("class/*.yml"), source_locale: "fr")).to contain_exactly_offences(
        I18nLint::Offence.new("Test/Description", examples.join("class/bad.yml").to_s, nil, nil, nil, nil,
                              "Each file should only have 1 top-level locale key.")
      )
    end
  end

  context "with a class rule that adds a custom message" do
    let(:klass) do
      Class.new(I18nLint::Rule) do
        def self.name = "Test::Message"

        def on_file(i18n_file)
          top_level_keys = i18n_file.parsed.flat_map(&:keys)
          return if top_level_keys.size < 2

          add_offence(i18n_file, "too many top-level keys: must be < 2, but is #{top_level_keys}")
        end
      end
    end

    before { I18nLint.register_rule(klass) }

    it "finds offences for the rule" do
      examples = Pathname.new(File.expand_path("../examples/", __dir__))
      expect(I18nLint.lint(examples.join("class/*.yml"), source_locale: "fr")).to contain_exactly_offences(
        I18nLint::Offence.new("Test/Message", examples.join("class/bad.yml").to_s, nil, nil, nil, nil,
                              'too many top-level keys: must be < 2, but is ["fr", "en"]')
      )
    end
  end

  def contain_exactly_offences(*offences)
    include(*offences).and have_attributes(size: offences.size)
  end

  def match_offences(offences)
    contain_exactly_offences(*offences)
  end
end
