# frozen_string_literal: true

require "i18nlint/highlighters/colour"

RSpec.describe I18nLint::Highlighters::Colour do
  describe ".indicate" do
    it "colours the given char positions" do
      text = "hello world"
      slices = [[5, 6]]
      expected = <<~TEXT.chomp
        hello\e[30;43m \e[0mworld
      TEXT
      expect(described_class.indicate(text, *slices)).to eql(expected)
    end

    context "when the slices include the last character" do
      it "colours the given char positions" do
        text = "_Premièrement publié:_ %{datetime}"
        slices = [[23, 34]]
        expected = <<~TEXT.chomp
          _Premièrement publié:_ \e[30;43m%{datetime}\e[0m
        TEXT

        expect(described_class.indicate(text, *slices)).to eql(expected)
      end
    end

    context "with multiple lines" do
      it "colours the given char positions" do
        text = <<~TEXT
          this is the first line
          and this is the second line
          oh what is this? it is a third line!
        TEXT

        match_slices = text.enum_for(:scan, "is").map { Regexp.last_match.offset(0) }
        actual = described_class.indicate(text, *match_slices)

        expected = <<~TEXT
          th\e[30;43mis\e[0m \e[30;43mis\e[0m the first line
          and th\e[30;43mis\e[0m \e[30;43mis\e[0m the second line
          oh what \e[30;43mis\e[0m th\e[30;43mis\e[0m? it \e[30;43mis\e[0m a third line!
        TEXT

        expect(actual).to eql(expected)
      end
    end
  end
end
