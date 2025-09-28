# frozen_string_literal: true

RSpec.describe I18nLint::Enumerator do
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

  it "enumerates each segment for a file" do
    instance = described_class.new(examples_dir.join("enumerator/*.yml"), source_locale: "en")

    expect(instance.each_segment.map { |segment| "#{segment.locale}:#{segment.key}" })
      .to match_array %w[en:one en:nested.one fr:one fr:nested.one de:one de:nested.one es:one es:nested.one]
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

    it "reads all files when instantiated" do
      calls = capture_method_calls(File, :read)
      instance = nil

      expect { instance = described_class.new(examples_dir.join("enumerator/*.yml"), source_locale: "en") }
        .to change { calls.size }.from(0).to(5) # all files should be read when initialized
      expect { instance.each_file.take(2) }
        .not_to change { calls.size }.from(5) # files should not be re-read
    end

    it "only parses what's needed" do
      calls = capture_method_calls(I18nLint::YamlWithLines, :parse)
      instance = described_class.new(examples_dir.join("enumerator/*.yml"), source_locale: "en")

      expect { instance.each_file.take(2) }
        .to change { calls.size }.from(0).to(2) # only some files should be parsed
      expect { instance.each_file.to_a }
        .to change { calls.size }.from(2).to(5) # rest of the files should be parsed
    end

    it "works with all kinds of yaml, but doesn't offer line numbers for everything" do
      segments = nil
      expect { segments = described_class.new(examples_dir.join("**/*.yml"), source_locale: "FR").each_segment.to_a }
        .not_to raise_error
      expect(segments.map(&:filepath)).to include examples_dir.join("all_sorts_of_yaml_syntax.yml").to_s

      # This format looks a little funky because this library assumes that the whole document is a hash and every
      # top-level key is a locale. We're deliberately using different yaml in this test to ensure we don't raise errors,
      # and with that comes the absence of `#key` in most segments.
      all_sorts = segments.select { _1.filepath == examples_dir.join("all_sorts_of_yaml_syntax.yml").to_s }
                          .map { "#{_1.locale}.#{_1.key}:#{_1.lineno || "<NO LINE>"}" }
      expect(all_sorts.join("\n")).to eq <<~KEYS.chomp
        lower.:2
        UPPER.:3
        false.:4
        no.:5
        map_alias.some_array.0:<NO LINE>
        map_alias.some_array.1:<NO LINE>
        map_alias.some_array.2:<NO LINE>
        map_alias.some_sequence.0:<NO LINE>
        map_alias.some_sequence.1:<NO LINE>
        map_alias.some_hash.c:12
        map_alias.some_hash.d:12
        map_alias.some_map.e:14
        map_alias.some_map.f:15
        map_copied.some_array.0:<NO LINE>
        map_copied.some_array.1:<NO LINE>
        map_copied.some_array.2:<NO LINE>
        map_copied.some_sequence.0:<NO LINE>
        map_copied.some_sequence.1:<NO LINE>
        map_copied.some_hash.c:12
        map_copied.some_hash.d:12
        map_copied.some_map.e:14
        map_copied.some_map.f:15
        map_extended.some_array.0:<NO LINE>
        map_extended.some_array.1:<NO LINE>
        map_extended.some_array.2:<NO LINE>
        map_extended.some_sequence.0:<NO LINE>
        map_extended.some_sequence.1:<NO LINE>
        map_extended.some_hash.c:12
        map_extended.some_hash.d:12
        map_extended.some_map.e:14
        map_extended.some_map.f:15
        map_extended.nested_sequence.0.a:20
        map_extended.nested_sequence.0.b:21
        map_extended.nested_sequence.1.a:22
        map_extended.nested_sequence.1.b:23
        map_alias_2.foo:26
        map_copied_2.1.some_array.0:<NO LINE>
        map_copied_2.1.some_array.1:<NO LINE>
        map_copied_2.1.some_array.2:<NO LINE>
        map_copied_2.1.some_sequence.0:<NO LINE>
        map_copied_2.1.some_sequence.1:<NO LINE>
        map_copied_2.1.some_hash.c:12
        map_copied_2.1.some_hash.d:12
        map_copied_2.1.some_map.e:14
        map_copied_2.1.some_map.f:15
        map_copied_2.2.foo:26
        map_extended_2.1.some_array.0:<NO LINE>
        map_extended_2.1.some_array.1:<NO LINE>
        map_extended_2.1.some_array.2:<NO LINE>
        map_extended_2.1.some_sequence.0:<NO LINE>
        map_extended_2.1.some_sequence.1:<NO LINE>
        map_extended_2.1.some_hash.c:12
        map_extended_2.1.some_hash.d:12
        map_extended_2.1.some_map.e:14
        map_extended_2.1.some_map.f:15
        map_extended_2.2.foo:26
        map_extended_2.extra:30
        sequence_alias.0:<NO LINE>
        sequence_alias.1:<NO LINE>
        sequence_copied.0:<NO LINE>
        sequence_copied.1:<NO LINE>
        sequence_extended.0.0:<NO LINE>
        sequence_extended.0.1:<NO LINE>
        sequence_extended.1:<NO LINE>
        sequence_alias_2.0:<NO LINE>
        sequence_alias_2.1:<NO LINE>
        sequence_copied_2.0.0:<NO LINE>
        sequence_copied_2.0.1:<NO LINE>
        sequence_copied_2.1.0:<NO LINE>
        sequence_copied_2.1.1:<NO LINE>
        sequence_extended_2.<<.0.0:<NO LINE>
        sequence_extended_2.<<.0.1:<NO LINE>
        sequence_extended_2.<<.1.0:<NO LINE>
        sequence_extended_2.<<.1.1:<NO LINE>
        string_double_left_arrow.<<:48
      KEYS
    end
  end
end
