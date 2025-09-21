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

  context "with a regex rule" do
    let(:regex) { /<special[^>]*> NOT ALLOWED/ }

    before { I18n::Lint.register_rule(regex) }

    it "finds offences for the rule" do
      examples = Pathname.new(File.expand_path("../examples/", __dir__))
      expect(I18n::Lint.lint(examples.join("regex/*.yml"), source_locale: "fr")).to contain_exactly_offences(
        I18n::Lint::Offence.new(regex, examples.join("regex/bad.yml").to_s, 2, "en", "hello",
                                "Hello <special> NOT ALLOWED eh")
      )
    end
  end

  context "with a proc rule" do
    let(:proc) { ->(_locale, key, text) { text.start_with?("NOTE:") unless key.end_with?("_note") } }

    before { I18n::Lint.register_rule(proc) }

    it "finds offences for the rule" do
      examples = Pathname.new(File.expand_path("../examples/", __dir__))
      expect(I18n::Lint.lint(examples.join("proc/*.yml"), source_locale: "de")).to contain_exactly_offences(
        I18n::Lint::Offence.new(proc, examples.join("proc/bad.yml").to_s, 2, "en", "hello", "NOTE: hello")
      )
    end
  end

  context "with a class rule" do
    let(:klass) do
      Class.new(I18n::Lint::Rule) do
        def self.description = "Each file should only have 1 top-level locale key."

        def on_file(i18n_file)
          top_level_keys = i18n_file.parsed.flat_map(&:keys)
          return if top_level_keys.size < 2

          add_offence(i18n_file)
        end
      end
    end

    before { I18n::Lint.register_rule(klass) }

    it "finds offences for the rule" do
      examples = Pathname.new(File.expand_path("../examples/", __dir__))
      expect(I18n::Lint.lint(examples.join("class/*.yml"), source_locale: "fr")).to contain_exactly_offences(
        I18n::Lint::Offence.new(klass, examples.join("class/bad.yml").to_s, nil, nil, nil,
                                File.read(examples.join("class/bad.yml")),
                                "Each file should only have 1 top-level locale key.")
      )
    end
  end

  context "with a class rule that adds a custom message" do
    let(:klass) do
      Class.new(I18n::Lint::Rule) do
        def on_file(i18n_file)
          top_level_keys = i18n_file.parsed.flat_map(&:keys)
          return if top_level_keys.size < 2

          add_offence(i18n_file, "too many top-level keys: must be < 2, but is #{top_level_keys}")
        end
      end
    end

    before { I18n::Lint.register_rule(klass) }

    it "finds offences for the rule" do
      examples = Pathname.new(File.expand_path("../examples/", __dir__))
      expect(I18n::Lint.lint(examples.join("class/*.yml"), source_locale: "fr")).to contain_exactly_offences(
        I18n::Lint::Offence.new(klass, examples.join("class/bad.yml").to_s, nil, nil, nil,
                                File.read(examples.join("class/bad.yml")),
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
