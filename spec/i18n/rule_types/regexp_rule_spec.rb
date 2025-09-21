# frozen_string_literal: true

RSpec.describe I18n::Lint::RuleTypes::RegexpRule do
  it "is registered" do
    expect(I18n::Lint::Registry.rule_types).to include(Regexp => described_class)
  end

  it "is used for rules registered by Regexp" do
    expect(I18n::Lint::Registry.register_rule(/match me/)).to be_a(described_class)
  end

  it "works on individual segments only for now" do
    rule = I18n::Lint::Registry.register_rule(/./)
    file = I18n::Lint::File.new

    expect { rule.on_segment(I18n::Lint::Segment.new(file:, text: "1")) }
      .to change { rule.take_offences.size }
      .to(1)

    expect do
      rule.on_segment_comparison(I18n::Lint::Segment.new(file:, text: "2"),
                                 I18n::Lint::Segment.new(file:, text: "3"))
      rule.on_file(file)
    end.not_to(change { rule.take_offences.size })
  end
end
