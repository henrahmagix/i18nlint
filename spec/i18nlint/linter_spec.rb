# rubocop:disable Style/FrozenStringLiteralComment -- we need mutable strings to test our immutability

# This class is mostly covered by cli_spec.
RSpec.describe I18nLint::Linter do
  it "avoids rules from mutating files and segments" do
    enum = instance_double(I18nLint::Enumerator)
    allow(I18nLint::Enumerator).to receive(:new).and_return(enum)

    files = [
      I18nLint::File.new(filepath: "locales/en.yml", parsed: { "en" => { "hi" => "hello" } },
                         raw: "en:\n  hi: hello\n"),
      I18nLint::File.new(filepath: "locales/fr.yml", parsed: { "fr" => { "hi" => "bonjour" } },
                         raw: "fr:\n  hi: bonjour\n")
    ]
    allow(enum).to receive(:each_file) { |&b| files.each(&b) }
    original_files = Marshal.dump(files)

    segments = [
      I18nLint::Segment.new(file: files[0], lineno: 2, key: "hi", text: "hello", locale: "en", source_locale: "en"),
      I18nLint::Segment.new(file: files[1], lineno: 2, key: "hi", text: "bonjour", locale: "fr", source_locale: "en")
    ]
    allow(enum).to receive(:each_segment) { |&b| segments.each(&b) }
    original_segments = Marshal.dump(segments)

    rule_class = Class.new(I18nLint::Rule) do
      @has_run_file = false
      @has_run_segment = false
      @has_run_comparison = false
      singleton_class.attr_accessor :has_run_file, :has_run_segment, :has_run_comparison

      def modify_file(file)
        file.filepath.prepend "/changed/"
        file.raw.concat "\nchanged: true"
        file.parsed.merge!(changed: true)
      end

      def on_file(file)
        self.class.has_run_file = true
        modify_file(file)
      end

      def modify_segment(segment)
        segment.lineno += 99
        segment.key.prepend "changed."
        segment.text.concat ": changed!"
        segment.locale = "aa"
        segment.source_locale.gsub!(/.*/, "zz")
      end

      def on_segment(segment)
        self.class.has_run_segment = true
        modify_file(segment.file)
        modify_segment(segment)
      end

      def on_segment_comparison(segment, source_segment)
        self.class.has_run_comparison = true
        modify_segment(segment)
        modify_segment(source_segment)
      end
    end

    allow(I18nLint::Registry).to receive(:rules).and_return [rule_class.new]

    linter = described_class.new(filepaths: "", source_locale: "en")
    linter.run
    linter.run_comparison

    expect(files).to eq Marshal.load(original_files) # rubocop:disable Security/MarshalLoad
    expect(segments).to eq Marshal.load(original_segments) # rubocop:disable Security/MarshalLoad

    has_run = %i[has_run_file has_run_segment has_run_comparison].to_h { [_1, rule_class.send(_1)] }
    expect(has_run).to eq has_run_file: true, has_run_segment: true, has_run_comparison: true
  end

  it "re-raises errors that occur within rules with the segment or file that had been reached" do
    enum = instance_double(I18nLint::Enumerator)
    allow(I18nLint::Enumerator).to receive(:new).and_return(enum)

    files = [
      I18nLint::File.new(filepath: "locales/en.yml", parsed: { "en" => { "hi" => "hello" } },
                         raw: "en:\n  hi: hello\n"),
      I18nLint::File.new(filepath: "locales/fr.yml", parsed: { "fr" => { "hi" => "bonjour" } },
                         raw: "fr:\n  hi: bonjour\n")
    ]
    allow(enum).to receive(:each_file) { |&b| files.each(&b) }

    segments = [
      I18nLint::Segment.new(file: files[0], lineno: 2, key: "hi", text: "hello", locale: "en", source_locale: "en"),
      I18nLint::Segment.new(file: files[1], lineno: 2, key: "hi", text: "bonjour", locale: "fr", source_locale: "en")
    ]
    allow(enum).to receive(:each_segment) { |&b| segments.each(&b) }

    rule_class = Class.new(I18nLint::Rule)
    allow(I18nLint::Registry).to receive(:rules).and_return [rule_class.new]

    linter = described_class.new(filepaths: "", source_locale: "en")

    rule_class.define_method(:on_file) { |_file| raise "file problem" }
    expect { linter.run }.to raise_error(
      I18nLint::ErrorOnFile, "on file locales/en.yml:\n  RuntimeError: file problem"
    )

    rule_class.define_method(:on_file) { |*| nil }
    rule_class.define_method(:on_segment) { |_segment| raise "segment problem" }
    expect { linter.run }.to raise_error(
      I18nLint::ErrorOnSegment, "on segment hi at locales/en.yml:2:\n  RuntimeError: segment problem"
    )

    rule_class.define_method(:on_segment) { |*| nil }
    rule_class.define_method(:on_segment_comparison) { |_segment, _source| raise "segment comparison problem" }
    expect { linter.run }.not_to raise_error
    expect { linter.run_comparison }.to raise_error(
      I18nLint::ErrorOnSegmentComparison, "on segment hi at locales/fr.yml:2 compared to hi at locales/en.yml:2:" \
                                          "\n  RuntimeError: segment comparison problem"
    )
  end
end

# rubocop:enable Style/FrozenStringLiteralComment
