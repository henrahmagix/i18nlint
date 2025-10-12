# frozen_string_literal: true

RSpec.describe I18nLint::Enumerator do
  let(:examples_dir) { Pathname.new File.expand_path "../examples", __dir__ }

  describe "File" do
    it "says what kind of source the file is" do
      expect(I18nLint::File.new(filepath: "a.rb")).to have_attributes(ruby?: true, yaml?: false, json?: false)
      expect(I18nLint::File.new(filepath: "b.yml")).to have_attributes(ruby?: false, yaml?: true, json?: false)
      expect(I18nLint::File.new(filepath: "c.yaml")).to have_attributes(ruby?: false, yaml?: true, json?: false)
      expect(I18nLint::File.new(filepath: "d.json")).to have_attributes(ruby?: false, yaml?: false, json?: true)
    end
  end

  describe "Segment" do
    it "can capture the interpolations in the text" do
      expect(I18nLint::Segment.new(text: "hello").interpolations).to eq []
      expect(I18nLint::Segment.new(text: "hello %{name} %{surname}").interpolations).to eq %i[name surname]
    end
  end

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

  it "enumerates each segment for a file" do
    instance = described_class.new(examples_dir.join("enumerator/*.yml"), source_locale: "en")

    expect(instance.each_segment.map { |segment| "#{segment.locale}:#{segment.key}" })
      .to match_array %w[en:one en:nested.one fr:one fr:nested.one de:one de:nested.one es:one es:nested.one]
  end

  it "doesn't enumerate into a segment of sequence values" do
    instance = described_class.new(examples_dir.join("types/sequence.yml"), source_locale: "en")

    expect(instance.each_segment.to_a).to contain_exactly(
      have_attributes(filepath: end_with("sequence.yml"), lineno: 2, key: "array", value: [nil, 1, 2, "three", "four"])
    )
  end

  it "each segment can say if it's the source locale" do
    instance = described_class.new(examples_dir.join("enumerator/*.yml"), source_locale: "en")

    expect(instance.each_segment.map { |segment| "#{segment.locale}:#{segment.key}:#{segment.source?}" })
      .to match_array %w[en:one:true en:nested.one:true fr:one:false fr:nested.one:false
                         de:one:false de:nested.one:false es:one:false es:nested.one:false]
  end

  it "yields only the files that are parsed" do
    instance = described_class.new(examples_dir.join("enumerator/*.yml"), source_locale: "en")

    expect { |probe| instance.each_file.take(2).each(&probe) }
      .to yield_successive_args(*[I18nLint::File] * 2) # only some files should be yielded
    expect { |probe| instance.each_file.each(&probe) }
      .to yield_successive_args(*[I18nLint::File] * 5) # all files should be yielded
  end

  it "yields only the segments that are needed" do
    instance = described_class.new(examples_dir.join("enumerator/*.yml"), source_locale: "en")

    allow(I18nLint::Segment).to receive(:new).and_call_original
    expect(instance.each_segment.take(3)).to match [I18nLint::Segment] * 3
    expect(I18nLint::Segment).to have_received(:new).exactly(3).times

    expect(instance.each_segment.to_a.size).to be > 3
  end

  define_negated_matcher :not_raise_error, :raise_error
  define_negated_matcher :not_output, :output

  it "ignores filepaths that don't exist" do
    expect { described_class.new([examples_dir.join("enumerator/*.yml"), "foo.yml"], source_locale: "FR") }
      .to not_output.to_stderr
      .and not_raise_error
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

    it "only reads what's needed" do
      calls = capture_method_calls(File, :read)
      instance = nil

      expect { instance = described_class.new(examples_dir.join("enumerator/*.yml"), source_locale: "en") }
        .not_to change(calls, :size)
      expect { instance.each_file.take(2) }
        .to change(calls, :size).from(0).to(2)
      expect { instance.each_file.take(3) }
        .to change(calls, :size).from(2).to(3)
    end

    it "only parses what's needed when enumerating files" do
      calls = capture_method_calls(I18nLint::YamlWithLines, :parse)
      instance = described_class.new(examples_dir.join("enumerator/*.yml"), source_locale: "en")

      expect { instance.each_file.take(2) }
        .to change(calls, :size).from(0).to(2) # only the yielded files should be parsed
      expect { instance.each_file.to_a }
        .to change(calls, :size).from(2).to(5) # rest of the files should be parsed
    end

    it "only parses what's needed when enumerating segments" do
      calls = capture_method_calls(I18nLint::YamlWithLines, :parse)
      instance = described_class.new(examples_dir.join("enumerator/num_segments/{3,2,1}.yml"), source_locale: "en")

      expect { instance.each_segment.take(1) }
        .to change(calls, :size).from(0).to(1) # only one file should be parsed for one segment
      expect { instance.each_segment.take(2) }
        .not_to change(calls, :size).from(1) # still the same first file being parsed cos it has 3 segments
      expect { instance.each_segment.take(4) }
        .to change(calls, :size).from(1).to(2) # parses the next file that has 2 segments
      expect { instance.each_segment.to_a }
        .to change(calls, :size).from(2).to(3) # parses all the files
    end

    it "works with all kinds of yaml, but doesn't offer line numbers for everything" do
      segments = nil
      # Find filepaths separately so we can ignore the config file: it's hard to do with an fnmatch.
      filepaths = Dir.glob(examples_dir.join("**/*.yml")).reject { _1.end_with?("/cli/config.yml") }
      expect { segments = described_class.new(filepaths, source_locale: "FR").each_segment.to_a }
        .not_to raise_error
      expect(segments.map(&:filepath)).to include examples_dir.join("all_sorts_of_yaml_syntax.yml").to_s

      # This format looks a little funky because this library assumes that the whole document is a hash and every
      # top-level key is a locale. We're deliberately using different yaml in this test to ensure we don't raise errors,
      # and with that comes the absence of `#key` in most segments.
      all_sorts = segments.select { _1.filepath == examples_dir.join("all_sorts_of_yaml_syntax.yml").to_s }
                          .map { "#{_1.locale}.#{_1.key}:#{_1.lineno || "<NO LINE>"}" }
      expect(all_sorts.join("\n")).to eq <<~KEYS.chomp
        stuff.lower:3
        stuff.UPPER:4
        stuff.false:5
        stuff.no:6
        map_alias.some_array:9
        map_alias.some_sequence:11
        map_alias.some_hash.c:13
        map_alias.some_hash.d:13
        map_alias.some_map.e:15
        map_alias.some_map.f:16
        map_copied.some_array:9
        map_copied.some_sequence:11
        map_copied.some_hash.c:13
        map_copied.some_hash.d:13
        map_copied.some_map.e:15
        map_copied.some_map.f:16
        map_extended.some_array:9
        map_extended.some_sequence:11
        map_extended.some_hash.c:13
        map_extended.some_hash.d:13
        map_extended.some_map.e:15
        map_extended.some_map.f:16
        map_extended.nested_sequence:21
        map_alias_2.foo:27
        map_copied_2.1.some_array:9
        map_copied_2.1.some_sequence:11
        map_copied_2.1.some_hash.c:13
        map_copied_2.1.some_hash.d:13
        map_copied_2.1.some_map.e:15
        map_copied_2.1.some_map.f:16
        map_copied_2.2.foo:27
        map_extended_2.1.some_array:9
        map_extended_2.1.some_sequence:11
        map_extended_2.1.some_hash.c:13
        map_extended_2.1.some_hash.d:13
        map_extended_2.1.some_map.e:15
        map_extended_2.1.some_map.f:16
        map_extended_2.2.foo:27
        map_extended_2.extra:31
        string_double_left_arrow.<<:34
      KEYS
    end
  end
end
