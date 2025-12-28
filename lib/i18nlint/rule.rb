# frozen_string_literal: true

require "i18nlint/rule_helper"

module I18nLint
  # A registered offence as reported by a rule.
  FileOffence = Struct.new(:rule, :filepath, :lineno, :text, :message, :highlight, keyword_init: true) do
    def key = nil
    def locale = nil
  end
  SegmentOffence = Struct.new(*FileOffence.members, :value, :locale, :key, keyword_init: true)
  CompareSegmentOffence = Struct.new(*SegmentOffence.members, :source_offence, keyword_init: true)

  # Base class for Class rule types.
  class Rule
    include RuleHelper

    attr_reader :config, :message

    @rule_classes = []

    class << self
      def enabled_by_default? = @enable_by_default.nil? || @enable_by_default
      def on_init_blocks      = @on_init_blocks ||= []

      def enable_by_default(bool)
        @enable_by_default = bool
      end

      def on_init(&block)
        on_init_blocks << block
      end

      def rule_key
        name.to_s.gsub(/^(::)?I18nLint::Rules?::/, "").gsub("::", "/")
      end

      attr_reader :rule_classes

      def inherited(rule_class)
        @rule_classes << rule_class
        super
      end
    end

    def initialize(config = {})
      @config = config
      @message = config["Message"] if config.is_a?(Hash)
      @offences = []

      @exclude = Array((config["Exclude"] if config.is_a?(Hash)))
      @always_include = @exclude.empty?

      self.class.on_init_blocks.each { |b| instance_exec(&b) }
    end

    def describe
      desc = " #{description}" if respond_to?(:description) && description
      desc ||= " #{self.class.description}" if self.class.respond_to?(:description) && self.class.description
      "#{self.class.rule_key}#{desc}"
    end

    def excluded?(filepath)
      return false if @always_include

      path = Pathname.new(filepath)
      @exclude.any? { |dir_pattern| path.fnmatch(dir_pattern) }
    end

    def add_offence(item, message = nil, highlight: nil)
      case item
      when File
        add_file_offence(item, message, highlight:)
      when Segment
        add_segment_offence(item, message, highlight:)
      else
        raise ArgumentError, "inapplicable offence type #{item.class}: #{item}"
      end
    end

    def add_file_offence(file, msg = nil, lineno: nil, source: nil, highlight: nil)
      @offences << FileOffence.new(
        rule: describe,
        filepath: file.filepath,
        lineno:,
        text: source, # don't print the whole file contents in the offence
        message: msg || message,
        highlight:
      )
    end

    def add_segment_offence(segment, msg = nil, highlight: nil)
      @offences << make_segment_offence(SegmentOffence, segment, describe, msg || message, highlight:)
    end

    def add_segment_compare_offence(segment, source_segment, msg = nil, src_msg = nil, highlight: nil, # rubocop:disable Metrics/ParameterLists
                                    source_highlight: nil)
      desc = describe
      o = make_segment_offence(CompareSegmentOffence, segment, desc, msg || message, highlight:)
      o.source_offence = make_segment_offence(SegmentOffence, source_segment, desc, src_msg,
                                              highlight: source_highlight)
      @offences << o
    end

    def take_offences
      @offences
    ensure
      @offences = []
    end

    private

    def make_segment_offence(offence_class, segment, description, message, highlight:)
      offence_class.new(
        rule: description,
        filepath: segment.filepath,
        lineno: segment.lineno,
        locale: segment.locale,
        key: segment.key,
        text: segment.text,
        message:,
        highlight:
      )
    end
  end
end
