# frozen_string_literal: true

RSpec.describe I18nLint::Enumerator do
  describe "File" do
    it "says what kind of source the file is" do
      expect(I18nLint::File.new(filepath: "a.rb")).to have_attributes(ruby?: true, yaml?: false, json?: false)
      expect(I18nLint::File.new(filepath: "b.yml")).to have_attributes(ruby?: false, yaml?: true, json?: false)
      expect(I18nLint::File.new(filepath: "c.yaml")).to have_attributes(ruby?: false, yaml?: true, json?: false)
      expect(I18nLint::File.new(filepath: "d.json")).to have_attributes(ruby?: false, yaml?: false, json?: true)
    end
  end

  describe "Segment" do
    it "says if it's the source" do
      expect(I18nLint::Segment.new(locale: "fr", source_locale: "en")).not_to be_source
      expect(I18nLint::Segment.new(locale: "en", source_locale: "en")).to be_source
    end
  end

  it "enumerates each segment across multiple files, and compares against the source locale" do
    temp_file "flat_en.yml",   "en:\n  one: one"
    temp_file "flat_fr.yml",   "fr:\n  one: un"
    temp_file "nested_en.yml", "en:\n  nested:\n    one: one"
    temp_file "nested_fr.yml", "fr:\n  nested:\n    one: un"
    temp_file "multiple.yml", <<~YML
      de:
        one: ein
        nested:
          one: ein
      es:
        one: uno
        nested:
          one: uno
    YML
    instance = described_class.new("#{ExampleFiles::DIR}/**/*.yml", source_locale: nil)

    expect(instance.each_segment.map { |segment| "#{segment.locale}:#{segment.key}" })
      .to match_array %w[en:one en:nested.one fr:one fr:nested.one de:one de:nested.one es:one es:nested.one]
  end

  it "accepts a path glob and says how many files it's going to enumerate" do
    # For this test, cover early versions of I18n that don't have `load_yaml`, so we can test a complex glob.
    I18n::Backend::Base.alias_method :load_yaml, :load_yml unless I18n::Backend::Base.method_defined?(:load_yaml)

    yaml_files  = random_yaml_files(3) + [temp_file("a/b/c.yaml", "en: {key: foo}")]
    _ruby_files = random_ruby_files(2)
    instance = described_class.new("#{ExampleFiles::DIR}/**/*.{yaml,yml}", source_locale: nil)

    expect(instance.num_files).to be 4
    expect(instance.each_file.to_a.size).to be instance.num_files
    expect(instance.each_segment.map(&:filepath).uniq).to match_array yaml_files
  end

  it "assigns the given source_locale to all segments" do
    instance = described_class.new(random_yaml_files(2), source_locale: "de")
    num_segments = instance.each_segment.to_a.size
    expect(instance.each_segment.map(&:source_locale).tally).to eq({ "de" => num_segments })
  end

  it "makes a segment for sequence values, where `:value` is set whilst `:text` is nil" do
    filepath = temp_file "sequence.yml", "en:\n  array: [~, 1, 2, three, four]"

    instance = described_class.new(filepath, source_locale: nil)

    expect(instance.each_segment.to_a).to contain_exactly(
      have_attributes(filepath:, lineno: 2, key: "array", text: nil, value: [nil, 1, 2, "three", "four"])
    )
  end

  it "makes a segment for plural values, where `:value` is set to the hash whilst `:text` is nil" do
    filepath = temp_file "plurals.yml", <<~YML
      en:
        how_many:
          one: One
          other: More than one
      fr:
        how_many:
          one: Un
          other: Pas un
      pl:
        how_many:
          one: Jeden
          few: Od dwóch do czterech
          many: Od pięciu do dziewięciu
          other: Nieużywane
    YML

    instance = described_class.new(filepath, source_locale: nil)

    # I18n < 1.9.1 doesn't symbolize the keys, so we do it here to have passing tests across all versions.
    segments = instance.each_segment.to_a
    segments.each do |segment|
      segment.locale = segment.locale.to_sym
      segment.value.transform_keys!(&:to_sym)
    end

    expect(segments).to contain_exactly(
      have_attributes(filepath:, lineno: 3, locale: :en, key: "how_many", text: nil,
                      value: { one: "One", other: "More than one" }),
      have_attributes(filepath:, lineno: 7, locale: :fr, key: "how_many", text: nil,
                      value: { one: "Un", other: "Pas un" }),
      have_attributes(filepath:, lineno: 11, locale: :pl, key: "how_many", text: nil,
                      value: {
                        one: "Jeden",
                        few: "Od dwóch do czterech",
                        many: "Od pięciu do dziewięciu",
                        other: "Nieużywane"
                      })
    )
  end

  it "each segment can say if it's the source locale" do
    filepath = temp_file "locales.yml", <<~YML
      en: {one: one}
      fr: {one: Un}
      pl: {one: Jeden}
    YML
    instance = described_class.new(filepath, source_locale: "pl")

    expect(instance.each_segment.map { |segment| "#{segment.locale}:#{segment.key}:#{segment.source?}" })
      .to match_array %w[en:one:false fr:one:false pl:one:true]
  end

  it "yields only the files that are parsed" do
    instance = described_class.new(random_files(5), source_locale: nil)

    expect { |probe| instance.each_file.take(2).each(&probe) }
      .to yield_successive_args(*[I18nLint::File] * 2) # only some files should be yielded
    expect { |probe| instance.each_file(&probe) }
      .to yield_successive_args(*[I18nLint::File] * 5) # all files should be yielded
  end

  it "yields only the segments that are needed" do
    instance = described_class.new(random_files(3, segments_per: 2), source_locale: nil)

    expect { |probe| instance.each_segment.take(3).each(&probe) }
      .to yield_successive_args(*[I18nLint::Segment] * 3) # only some segments should be yielded
    expect { |probe| instance.each_segment(&probe) }
      .to yield_successive_args(*[I18nLint::Segment] * 6) # all segments should be yielded
  end

  define_negated_matcher :not_raise_error, :raise_error

  it "ignores filepaths that don't exist" do
    expect { described_class.new("foo.yml", source_locale: "FR") }
      .to output("").to_stderr
      .and output("").to_stdout
      .and not_raise_error
  end

  describe "file reading and parsing" do
    def capture_method_calls(object, method, &filter)
      calls = []
      allow(object).to receive(method).and_wrap_original do |m, *args, **kwargs, &block|
        calls << [args, kwargs, block] unless block_given? && filter[caller_locations] == false
        m.call(*args, **kwargs, &block)
      end
      calls
    end

    it "only reads what's needed" do
      calls = capture_method_calls(File, :read)
      instance = nil

      expect { instance = described_class.new(random_files(3), source_locale: nil) }
        .not_to change(calls, :size)
      expect { instance.each_file.take(2) }
        .to change(calls, :size).from(0).to(2)
      expect { instance.each_file.take(3) }
        .to change(calls, :size).from(2).to(3)
    end

    def capture_i18n_loads
      yaml = capture_method_calls(I18nLint::YamlWithLines, :parse)
      ruby = capture_method_calls(IO, :read) do |locs|
        locs.any? do |loc|
          loc.base_label.to_s == "load_rb" && loc.absolute_path == LOAD_RB_PATH
        end
      end

      CombinedArray.new([yaml, ruby])
    end

    LOAD_RB_PATH = I18n::Backend::Base.instance_method(:load_rb).source_location[0] # rubocop:disable Lint/ConstantDefinitionInBlock

    CombinedArray = Struct.new(:arrays) do # rubocop:disable Lint/ConstantDefinitionInBlock
      def size = arrays.sum(&:size)
      def length = size
      def count = size
    end

    it "only parses what's needed when enumerating files" do
      calls = capture_i18n_loads
      instance = described_class.new(random_files(5), source_locale: nil)

      expect { instance.each_file.take(2) }
        .to change(calls, :size).from(0).to(2) # only the yielded files should be parsed
      expect { instance.each_file.to_a }
        .to change(calls, :size).from(2).to(5) # rest of the files should be parsed
    end

    it "only parses what's needed when enumerating segments" do
      calls = capture_i18n_loads
      instance = described_class.new(random_files(3, segments_per: 2), source_locale: nil)

      expect { instance.each_segment.take(1) }
        .to change(calls, :size).from(0).to(1) # only one file should be parsed for one segment
      expect { instance.each_segment.take(2) }
        .not_to change(calls, :size).from(1) # still the same first file being parsed cos it has 2 segments
      expect { instance.each_segment.take(4) }
        .to change(calls, :size).from(1).to(2) # parses the next file that has 2 segments
      expect { instance.each_segment.to_a }
        .to change(calls, :size).from(2).to(3) # parses all the files
    end

    it "memoises the loaded files so subsequent iterations are much faster" do
      duration = proc do |&b|
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        b.call
        Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
      end

      instance = described_class.new(random_yaml_files + random_ruby_files, source_locale: nil)

      first_duration  = duration.call { instance.each_file.to_a }
      second_duration = duration.call { instance.each_file.to_a }

      expect(second_duration).to be < first_duration / 50
    end

    it "works with all kinds of yaml, but doesn't offer line numbers for everything" do
      filepath = temp_file "all_sorts_of_yaml_syntax.yml", <<~YAML
        # this is a comment
        stuff:
          lower: lowercase
          UPPER: UPPERCASE
          no: this is false
          'no': norwegian

        map_alias: &map
          some_array: [1, 2, 3]
          some_sequence:
            - a
            - b
          some_hash: {c: 'c', d: 'd'}
          some_map:
            e: 'e'
            f: 'f'
        map_copied: *map
        map_extended:
          <<: *map
          nested_sequence:
            - a: a
              b: b
            - a: 1
              b: 2

        map_alias_2: &map_2
          foo: bar
        map_copied_2: {1: *map, 2: *map_2}
        map_extended_2:
          <<: {1: *map, 2: *map_2}
          extra: hello

        string_double_left_arrow:
          <<: "hello"
      YAML

      segments = nil
      expect { segments = described_class.new(filepath, source_locale: "FR").each_segment.to_a }
        .not_to raise_error
      expect(segments.map(&:filepath).uniq).to eq [filepath]

      # This format looks a little funky because this library assumes that the whole document is a hash and every
      # top-level key is a locale. We're deliberately using different yaml in this test to ensure we don't raise errors,
      # and with that comes the absence of `#key` in most segments.
      all_sorts = segments.map { "#{_1.locale}.#{_1.key}:#{_1.lineno || "<NO LINE>"}" }
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
