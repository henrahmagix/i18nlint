# frozen_string_literal: true

require "i18nlint/highlighters/below_line"

RSpec.describe I18nLint::Highlighters::BelowLine do
  describe ".indicate" do
    it "raises error for bad slices" do
      expect { described_class.indicate("", 1) }
        .to raise_error(ArgumentError, "must be given 1 or more tuples of Integer, but was called with 1")
      expect { described_class.indicate("", [1]) }
        .to raise_error(ArgumentError, "must be given 1 or more tuples of Integer, but was called with [1]")
      expect { described_class.indicate("", [[1, 2]]) }
        .to raise_error(ArgumentError, "must be given 1 or more tuples of Integer, but was called with [[1, 2]]")
      expect { described_class.indicate("", [1, 2]) }
        .not_to raise_error
    end

    it "adds ^ indicators on the line below the given char positions" do
      text = "hello world"
      slices = [[5, 6], [7, 11]]
      expected = <<~TEXT.chomp
        hello world
             ^ ^^^^
      TEXT
      expect(described_class.indicate(text, *slices)).to eql(expected)
    end

    it "allows messages to be appended to indicated lines by the same index" do
      text = <<~TEXT
        hello world
        what a lovely day it is
      TEXT
      slices = [[5, 6], [7, 11], [16, 19]]
      messages = ["space here", "this is another issue"]
      expected = <<~TEXT
        hello world
             ^ ^^^^ space here; this is another issue
        what a lovely day it is
            ^^^
      TEXT
      expect(described_class.indicate(text, *slices, messages:)).to eql(expected)
    end

    it "shows nil message so it's obvious which message goes with which indication" do
      text = <<~TEXT
        hello world
        what a lovely day it is
      TEXT
      slices = [[5, 6], [7, 11], [16, 19], [26, 35]]
      messages = ["space here", nil, nil, "this is another issue"]
      expected = <<~TEXT
        hello world
             ^ ^^^^ space here; <nil>
        what a lovely day it is
            ^^^       ^^^^^^^^^ <nil>; this is another issue
      TEXT
      expect(described_class.indicate(text, *slices, messages:)).to eql(expected)
    end

    it "adds ^ indicators on the line below the given char positions when they include the last character" do
      text = "_Premièrement publié:_ %{datetime}"
      slices = [[23, 34]]
      expected = <<~TEXT.chomp
        _Premièrement publié:_ %{datetime}
                               ^^^^^^^^^^^
      TEXT

      expect(described_class.indicate(text, *slices)).to eql(expected)
    end

    it "adds ^ indicators on the line below the given char positions, even when they span across multiple lines" do
      text = <<~TEXT
        one here, and then from here and go
        aaaaaaaaaaaalllllllllll the way
        to here! and then stop.
      TEXT
      slices = [[4, 8], [24, 76]] # highlights count newline characters, which aren't visible or indicated
      expected = <<~TEXT
        one here, and then from here and go
            ^^^^                ^^^^^^^^^^^
        aaaaaaaaaaaalllllllllll the way
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
        to here! and then stop.
        ^^^^^^^^
      TEXT

      expect(described_class.indicate(text, *slices)).to eql(expected)
    end

    it "adds the ^ indicators in the correct order when the given char positions are not in order" do
      text = <<~TEXT
        hello world
        STOP
      TEXT
      slices = [[5, 6], [0, 1], [12, 16]]
      expected = <<~TEXT
        hello world
        ^    ^
        STOP
        ^^^^
      TEXT

      expect(described_class.indicate(text, *slices)).to eql(expected)
    end
  end
end
