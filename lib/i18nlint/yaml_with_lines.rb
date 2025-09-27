# frozen_string_literal: true

module I18nLint
  # Parse YAML such that every value is a ValueWithLineNumbers.
  class YamlWithLines
    ValueWithLineNumbers = Struct.new(:value, :lines)

    def self.parse(yaml)
      handler = Psych::TreeWithLineNumbersBuilder.new
      handler.parser = Psych::Parser.new(handler)
      handler.parser.parse(yaml)
      Psych::Visitors::ToRubyWithLineNumbers.create.accept(handler.root)
    end

    def self.walk(val, key_parts = [], &)
      case val
      when ValueWithLineNumbers
        yield key_parts, val.value, val.lines.first, val.lines.last
      when Hash
        val.each { |each_key, each_val| walk(each_val, key_parts + [each_key], &) }
      when Enumerable
        val.each_with_index { |each_val, each_key| walk(each_val, key_parts + [each_key], &) }
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

class Psych::TreeWithLineNumbersBuilder < Psych::TreeBuilder # rubocop:disable Style/Documentation,Style/ClassAndModuleChildren
  attr_accessor :parser

  def scalar(*args)
    node = Psych::Nodes::ScalarWithLineNumber.new(*args, parser.mark.line)
    @last.children << node
    node
  end
end

class Psych::Visitors::ToRubyWithLineNumbers < Psych::Visitors::ToRuby # rubocop:disable Style/Documentation,Style/ClassAndModuleChildren
  def visit_Psych_Nodes_ScalarWithLineNumber(node) # rubocop:disable Naming/MethodName
    visit_Psych_Nodes_Scalar(node)
  end

  private

  def revive_hash(hash, node) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity,Metrics/AbcSize,Metrics/MethodLength
    node.children.each_slice(2) do |k, v| # rubocop:disable Metrics/BlockLength
      key = accept(k)
      val = accept(v)

      if v.is_a? Psych::Nodes::ScalarWithLineNumber
        start_line = end_line = v.line_number + 1

        start_line = k.line_number + 1 if k.is_a? Psych::Nodes::ScalarWithLineNumber
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
        hash[key] = val
      end
    end

    hash
  end
end
