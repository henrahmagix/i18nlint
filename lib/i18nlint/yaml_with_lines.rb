# frozen_string_literal: true

# rubocop:disable Style/OneClassPerFile
module I18nLint
  # Parse YAML such that every value is a ValueWithLineNumbers.
  class YamlWithLines
    ValueWithLineNumbers = Struct.new(:value, :lines)

    class << self
      def dupe_segments_by_file = @dupe_segments_by_file ||= Hash.new { |h, k| h[k] = {} }

      # I18n, up to 1.14 as of writing, always unsafe-loads YAML because it should be from devs, not user-supplied. This
      # is why we don't bother defining `safe_load` methods here. If any NoMethodError exceptions are being raised for a
      # `safe_load*` method being called, please look into the version of I18n to see if it's changed, or if our
      # patching-in of this class has a bug and is effecting other YAML-loading classes.

      def unsafe_load(yaml, filename: nil, fallback: false, symbolize_names: false, freeze: false, # rubocop:disable Metrics/ParameterLists
                      strict_integer: false, parse_symbols: true)
        result = parse(yaml, filename:)
        return fallback unless result

        Psych::Visitors::ToRubyWithLineNumbers.create(symbolize_names:, freeze:, strict_integer:, parse_symbols:)
                                              .accept(result)[0]
      end

      # copy-paste from Psych.
      def unsafe_load_file(filename, **kwargs)
        ::File.open(filename, "r:bom|utf-8") do |f|
          unsafe_load f, filename: filename, **kwargs
        end
      end

      alias load_file unsafe_load_file # I18n relies on unsafe-loading, and < 1.8 relies on Psych defaulting to unsafe.

      def parse(yaml, filename: nil)
        handler = Psych::TreeWithLineNumbersBuilder.new
        handler.parser = Psych::Parser.new(handler)
        handler.parser.parse(yaml, filename:)
        dupe_segments_by_file[filename] = handler.duplicate_segments
        handler.root
      end

      def walk(val, key_parts = [], yield_hash_when: nil, &block)
        case val
        when ValueWithLineNumbers then yield key_parts, val.value, *first_last_lines(val)
        when Hash
          if yield_hash_when&.call(val)
            yield key_parts, val.transform_values(&:value), *first_last_lines(val)
          else
            val.each { |each_key, each_val| walk(each_val, key_parts + [each_key], yield_hash_when:, &block) }
          end
        else yield key_parts, val
        end
      end

      private

      def first_last_lines(val)
        case val
        when ValueWithLineNumbers
          [val.lines.first, val.lines.last]
        when Hash
          [val.values.first.lines.first, val.values.last.lines.last]
        end
      end
    end
  end
end

# Copied from https://gist.github.com/johncarney/7332f7b2075b86ea52177a4a82453806
# I've edited it to apply line numbers to sequence values too, even though they're unlikely to be used in i18n.
=begin # rubocop:disable Style/BlockComments
Custom Psych parser that captures line number information from a YAML file.

For a project I'm working on I need to be able to determine which line(s) in a YAML
file a particular value comes from. There are a few bits of advice on the internet
about this, the best of them that I've found involves monkey-patching, which is a
fairly low bar for "best" in my opinion. I found it on Stack Overflow:

  https://stackoverflow.com/questions/29462856/loading-yaml-with-line-number-for-each-key

Here's my take without monkey-patching. It deals with values spanning multiple lines
and handles YAML's << (insertion) operator, borrowing liberally from Psych's source code
to do so.
=end

require "psych"

class Psych::Nodes::ScalarWithLineNumber < Psych::Nodes::Scalar # rubocop:disable Style/Documentation,Style/ClassAndModuleChildren
  attr_reader :line_number

  def initialize(*args, line_number)
    super(*args)
    @line_number = line_number
  end
end

class Psych::Nodes::SequenceWithLineNumber < Psych::Nodes::Sequence # rubocop:disable Style/Documentation,Style/ClassAndModuleChildren
  attr_reader :line_number

  def initialize(*args, line_number)
    super(*args)
    @line_number = line_number
  end
end

class Psych::TreeWithLineNumbersBuilder < Psych::TreeBuilder # rubocop:disable Style/Documentation,Style/ClassAndModuleChildren
  attr_accessor :parser

  # Track duplicate segments across the same file.
  class DuplicatesTracker
    def initialize
      @levels = []
      @keys = []
      @level = -1
    end

    def duplicate_segments
      @keys.group_by(&:first)
           .reject { |_key, key_positions| key_positions.size < 2 }
           .transform_values { |key_positions| key_positions.map(&:last) }
    end

    def start_map!
      @level += 1
      @_last_was_scalar = false
    end

    def end_map!
      @level -= 1
      @_last_was_scalar = false
      @levels.pop
    end

    def add_scalar!(val, lineno)
      if @_last_was_scalar
        @_last_was_scalar = false
        @keys << [@levels.join("."), lineno]
        return
      end

      @_last_was_scalar = true
      @levels[@level] = val
    end
  end

  def initialize(...)
    super
    @_dup_tracker = DuplicatesTracker.new
  end

  def duplicate_segments = @_dup_tracker.duplicate_segments

  def scalar(*args)
    @_dup_tracker.add_scalar!(args[0], parser.mark.line + 1)
    node = Psych::Nodes::ScalarWithLineNumber.new(*args, parser.mark.line)
    @last.children << node
    node
  end

  def start_mapping(...)
    @_dup_tracker.start_map!
    super
  end

  def end_mapping(...)
    @_dup_tracker.end_map!
    super
  end

  def start_sequence(*args)
    node = Psych::Nodes::SequenceWithLineNumber.new(*args, parser.mark.line)
    @last.children << node
    push node
  end

  def end_sequence
    node = pop
    set_end_location(node)
    node
  end
end

class Psych::Visitors::ToRubyWithLineNumbers < Psych::Visitors::ToRuby # rubocop:disable Style/Documentation,Style/ClassAndModuleChildren
  def visit_Psych_Nodes_ScalarWithLineNumber(node) # rubocop:disable Naming/MethodName
    visit_Psych_Nodes_Scalar(node)
  end

  def visit_Psych_Nodes_SequenceWithLineNumber(node) # rubocop:disable Naming/MethodName
    visit_Psych_Nodes_Sequence(node)
  end

  if Gem.loaded_specs["psych"].version < Gem::Version.create("3.2.0")
    def self.create(...)
      super()
    end
  elsif Gem.loaded_specs["psych"].version < Gem::Version.create("5.0.0")
    def self.create(*args, strict_integer:, parse_symbols:, **kwargs) # rubocop:disable Lint/UnusedMethodArgument
      super(*args, **kwargs)
    end
  elsif Gem.loaded_specs["psych"].version < Gem::Version.create("5.3.0")
    def self.create(*args, parse_symbols:, **kwargs) # rubocop:disable Lint/UnusedMethodArgument
      super(*args, **kwargs)
    end
  end

  private

  def revive_hash(hash, node, tagged = false) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity,Metrics/AbcSize,Metrics/MethodLength,Style/OptionalBooleanParameter
    node.children.each_slice(2) do |k, v| # rubocop:disable Metrics/BlockLength
      key = accept(k)
      val = accept(v)

      if v.is_a?(Psych::Nodes::ScalarWithLineNumber) || v.is_a?(Psych::Nodes::SequenceWithLineNumber)
        start_line = end_line = v.line_number + 1

        start_line = k.line_number + 1 if k.is_a?(v.class)
        val = I18nLint::YamlWithLines::ValueWithLineNumbers.new(val, start_line..end_line)
      end

      if key == "<<" && k.tag != "tag:yaml.org,2002:str"
        case v
        when Psych::Nodes::Alias, Psych::Nodes::Mapping
          begin
            hash.merge! val
          rescue TypeError
            hash[key] = val
          end
        when Psych::Nodes::Sequence
          begin
            h = {}
            val.reverse_each do |value|
              h.merge! value
            end
            hash.merge! h
          rescue TypeError
            hash[key] = val
          end
        else
          hash[key] = val
        end
      else
        if !tagged && @symbolize_names && key.is_a?(String)
          key = key.to_sym
        elsif !@freeze && respond_to?(:deduplicate)
          key = deduplicate(key)
        end

        hash[key] = val
      end
    end

    hash
  end
end
# rubocop:enable Style/OneClassPerFile
