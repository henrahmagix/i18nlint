# frozen_string_literal: true

RSpec.describe I18nLint::RuleTypes::ClassRule do
  it "is registered" do
    expect(I18nLint::Registry.rule_types).to include(Class => described_class)
  end

  it "is used for rules registered by Class" do
    expect(
      I18nLint::Registry.register_rule(
        Class.new(I18nLint::Rule) { def on_segment(*); end }
      )
    ).to be_a(described_class)
  end

  it "works on all iteration methods" do
    klass = Class.new(I18nLint::Rule) do
      def on_segment(segment) = add_offence(segment)
      def on_segment_comparison(segment, source_segment) = add_offence(segment, "compared to #{source_segment}")
      def on_file(file) = add_offence(file)
    end

    rule = I18nLint::Registry.register_rule(klass)
    file = I18nLint::File.new(parsed: {})

    expect { rule.on_segment(I18nLint::Segment.new(file:, text: "1")) }
      .to change { rule.take_offences.size }
      .to(1)

    expect do
      rule.on_segment_comparison(I18nLint::Segment.new(file:, text: "2"),
                                 I18nLint::Segment.new(file:, text: "3"))
    end.to change { rule.take_offences.size }
       .to(1)

    expect { rule.on_file(file) }
      .to change { rule.take_offences.size }
      .to(1)
  end

  context "when none of the iteration methods are defined" do
    it "raises an error, since it'll never get run because method detection happens at registration" do
      expect do
        I18nLint::Registry.register_rule(
          Class.new(I18nLint::Rule) do
            def self.name = "TestClassRule"
            def self.to_s = name
          end
        )
      end.to raise_error(
        described_class::WillNeverRun,
        /ClassRule TestClassRule will never be used/
      )
    end
  end
end
