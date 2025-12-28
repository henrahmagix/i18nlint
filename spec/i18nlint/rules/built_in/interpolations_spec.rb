# frozen_string_literal: true

RSpec.describe I18nLint::Rules::BuiltIn::Interpolations do
  it "reports no offences for correct interpolations" do
    expect_no_segment_offences <<~TXT
      Hello %{name|there}, your percentage is %%%<pcnt>.d
    TXT
  end

  it "reports offence when broken in a segment" do
    expect_segment_offence <<~TXT
      Hello % {name}"
            ^^^^^^^^ broken
      Hello %{ name}"
            ^^^^^^^^ broken
      Hello %{name }"
            ^^^^^^^^ broken
    TXT
  end

  it "reports offence for extra in segment compared to source" do
    expect_comparison_offence <<~SEGMENT, <<~SOURCE, locale: :fr, source_locale: :en
      Bonjour %{name} %{surname}
                      ^^^^^^^^^^ extra in fr: surname
    SEGMENT
      Hello %{name}
    SOURCE
  end

  it "reports offence for missing in segment compared to source" do
    expect_comparison_offence <<~SEGMENT, <<~SOURCE, locale: :fr, source_locale: :en
      Bonjour %{name}
    SEGMENT
      Hello %{name} %{surname}
                    ^^^^^^^^^^ missing in fr: surname
    SOURCE
  end

  it "reports offence for both extra and missing in segment compared to source" do
    expect_comparison_offence <<~SEGMENT, <<~SOURCE, locale: :fr, source_locale: :en
      Bonjour %{honourific} %{name}
              ^^^^^^^^^^^^^ extra in fr: honourific
    SEGMENT
      Hello %{name} %{surname}
                    ^^^^^^^^^^ missing in fr: surname
    SOURCE
  end

  it "reports no offences for a segment that matches the source" do
    expect_no_comparison_offences <<~SEGMENT, <<~SOURCE, locale: :fr, source_locale: :en
      Bonjour %{honourific} %{name} %{surname}
    SEGMENT
      Hello %{honourific} %{name} %{surname}
    SOURCE
  end
end
