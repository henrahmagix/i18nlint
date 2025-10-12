# frozen_string_literal: true

# TODO: get line numbers for sequences, e.g.
# abbr_month_names: [~, Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec]

module I18nLint
  # Parse YAML such that every value is a ValueWithLineNumbers.
  class YamlWithLines
    ValueWithLineNumbers = Struct.new(:value, :lines)

    class << self
      def unsafe_load(yaml, filename: nil, fallback: false, symbolize_names: false, freeze: false, # rubocop:disable Metrics/ParameterLists
                      strict_integer: false)
        result = parse(yaml, filename:)
        return fallback unless result

        Psych::Visitors::ToRubyWithLineNumbers.create(symbolize_names:, freeze:, strict_integer:).accept(result)[0]
      end

      def unsafe_load_file filename, **kwargs
        ::File.open(filename, "r:bom|utf-8") do |f|
          unsafe_load f, filename: filename, **kwargs
        end
      end

      alias load_file unsafe_load_file

      def parse(yaml, filename: nil)
        handler = Psych::TreeWithLineNumbersBuilder.new
        handler.parser = Psych::Parser.new(handler)
        handler.parser.parse(yaml, filename:)
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

  def scalar(*args)
    node = Psych::Nodes::ScalarWithLineNumber.new(*args, parser.mark.line)
    @last.children << node
    node
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

  private

  def revive_hash(hash, node, tagged = false) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity,Metrics/AbcSize,Metrics/MethodLength,Style/OptionalBooleanParameter
    node.children.each_slice(2) do |k, v| # rubocop:disable Metrics/BlockLength
      key = accept(k)
      val = accept(v)

      if v.is_a? Psych::Nodes::ScalarWithLineNumber
        start_line = end_line = v.line_number + 1

        start_line = k.line_number + 1 if k.is_a? Psych::Nodes::ScalarWithLineNumber
        val = I18nLint::YamlWithLines::ValueWithLineNumbers.new(val, start_line..end_line)
      elsif v.is_a? Psych::Nodes::SequenceWithLineNumber
        start_line = end_line = v.line_number + 1

        start_line = k.line_number + 1 if k.is_a? Psych::Nodes::SequenceWithLineNumber
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
        elsif !@freeze
          key = deduplicate(key)
        end

        hash[key] = val
      end
    end

    hash
  end
end
