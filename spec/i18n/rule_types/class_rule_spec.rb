# frozen_string_literal: true

RSpec.describe I18n::Lint::RuleTypes::ClassRule do
  it "is registered" do
    expect(I18n::Lint::Registry.rule_types).to include(Class => described_class)
  end

  it "is used for rules registered by Class" do
    expect(I18n::Lint::Registry.register_rule(Class.new(I18n::Lint::Rule))).to be_a(described_class)
  end

  it "works on all iteration types" do
    klass = Class.new(I18n::Lint::Rule) do
      def on_segment(segment) = add_offence(segment)
      def on_segment_comparison(segment, source_segment) = add_offence(segment, "compared to #{source_segment}")
      def on_file(file) = add_offence(file)
    end

    rule = I18n::Lint::Registry.register_rule(klass)
    file = I18n::Lint::Linter::File.new(parsed: {})

    expect { rule.on_segment(I18n::Lint::Linter::Segment.new(file:, text: "1")) }
      .to change { rule.take_offences.size }
      .to(1)

    expect do
      rule.on_segment_comparison(I18n::Lint::Linter::Segment.new(file:, text: "2"),
                                 I18n::Lint::Linter::Segment.new(file:, text: "3"))
    end.to change { rule.take_offences.size }
       .to(1)

    expect { rule.on_file(file) }
      .to change { rule.take_offences.size }
      .to(1)
  end
end
