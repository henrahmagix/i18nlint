# frozen_string_literal: true

require "i18nlint/highlighters/indicate_below_line"

RSpec.describe I18nLint::Highlighters::IndicateBelowLine do
  describe ".indicate" do
    it "adds ^ indicators on the line below the given char positions" do
      text = "hello world"
      slices = [[5, 6]]
      expected = <<~TEXT.chomp
        hello world
             ^
      TEXT
      expect(described_class.indicate(text, *slices)).to eql(expected)
    end

    context "when the slices include the last character" do
      it "adds ^ indicators on the line below the given char positions" do
        text = "_Premièrement publié:_ %{datetime}"
        slices = [[23, 34]]
        expected = <<~TEXT.chomp
          _Premièrement publié:_ %{datetime}
                                 ^^^^^^^^^^^
        TEXT

        expect(described_class.indicate(text, *slices)).to eql(expected)
      end
    end

    context "with multiple lines" do
      it "adds ^ indicators on the line below the given char positions" do
        text = <<~TEXT
          this is the first line
          and this is the second line
          oh what is this? it is a third line!
        TEXT

        match_slices = text.enum_for(:scan, "is").map { Regexp.last_match.offset(0) }
        actual = described_class.indicate(text, *match_slices)

        expected = <<~TEXT
          this is the first line
            ^^ ^^
          and this is the second line
                ^^ ^^
          oh what is this? it is a third line!
                  ^^   ^^     ^^
        TEXT

        expect(actual).to eql(expected)
      end
    end
  end
end
