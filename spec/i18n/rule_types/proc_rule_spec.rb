# frozen_string_literal: true

RSpec.describe I18n::Lint::RuleTypes::ProcRule do
  it "is registered" do
    expect(I18n::Lint::Registry.rule_types).to include(Proc => described_class)
  end

  it "is used for rules registered by Proc" do
    expect(I18n::Lint::Registry.register_rule(proc {})).to be_a(described_class)
  end

  it "works on individual segments only" do
    rule = I18n::Lint::Registry.register_rule(proc { true })
    file = I18n::Lint::File.new

    expect { rule.on_segment(I18n::Lint::Segment.new(file:, text: "1")) }
      .to change { rule.take_offences.size }
      .to(1)

    expect do
      rule.on_segment_comparison(I18n::Lint::Segment.new(file:, text: "2"),
                                 I18n::Lint::Segment.new(file:, text: "3"))
    end.not_to(change { rule.take_offences.size })

    expect { rule.on_file(file) }
      .not_to(change { rule.take_offences.size })
  end
end
