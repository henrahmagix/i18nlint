# frozen_string_literal: true

RSpec.describe I18n::Lint::Enumerator do
  let(:examples_dir) { Pathname.new File.expand_path "../examples", __dir__ }

  it "enumerates each file" do
    instance = described_class.new(examples_dir.join("enumerator/*.yml"), source_locale: "en")

    expect(instance.each_file.map(&:filepath))
      .to match_array [
        examples_dir.join("enumerator/flat_en.yml").to_s,
        examples_dir.join("enumerator/flat_fr.yml").to_s,
        examples_dir.join("enumerator/nested_en.yml").to_s,
        examples_dir.join("enumerator/nested_fr.yml").to_s,
        examples_dir.join("enumerator/multiple.yml").to_s
      ]
  end

  it "enumerates each segment" do
    instance = described_class.new(examples_dir.join("enumerator/*.yml"), source_locale: "en")

    expect(instance.each_segment.map { |segment| "#{segment.locale}:#{segment.key}" })
      .to match_array %w[en:one en:nested.one fr:one fr:nested.one de:one de:nested.one es:one es:nested.one]
  end

  describe "file reading and parsing" do
    def capture_method_calls(object, method)
      calls = []
      allow(object).to receive(method).and_wrap_original do |m, *args, **kwargs, &block|
        calls << [args, kwargs, block]
        m.call(*args, **kwargs, &block)
      end
      calls
    end

    it "reads all files" do
      calls = capture_method_calls(File, :read)
      instance = nil

      expect { instance = described_class.new(examples_dir.join("enumerator/*.yml"), source_locale: "en") }
        .to change { calls.size }.from(0).to(5) # all files should be read when initialized
      expect { instance.each_file.take(2) }
        .not_to change { calls.size }.from(5) # files should not be re-read
    end

    it "only parses what's needed" do
      calls = capture_method_calls(YAML, :safe_load)
      instance = described_class.new(examples_dir.join("enumerator/*.yml"), source_locale: "en")

      expect { instance.each_file.take(2) }
        .to change { calls.size }.from(0).to(2) # only some files should be parsed
      expect { instance.each_file.to_a }
        .to change { calls.size }.from(2).to(5) # rest of the files should be parsed
    end

    it "yields only the files that are parsed" do
      instance = described_class.new(examples_dir.join("enumerator/*.yml"), source_locale: "en")

      expect { |probe| instance.each_file.take(2).each(&probe) }
        .to yield_successive_args(*[I18n::Lint::File] * 2) # only some files should be yielded
      expect { |probe| instance.each_file.each(&probe) }
        .to yield_successive_args(*[I18n::Lint::File] * 5) # all files should be yielded
    end

    it "yields only the segments that are needed" do
      instance = described_class.new(examples_dir.join("enumerator/*.yml"), source_locale: "en")

      allow(I18n::Lint::Segment).to receive(:new).and_call_original
      expect(instance.each_segment.take(3)).to match [I18n::Lint::Segment] * 3
      expect(I18n::Lint::Segment).to have_received(:new).exactly(3).times
    end
  end
end
