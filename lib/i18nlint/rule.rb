# frozen_string_literal: true

module I18nLint
  # A registered offence as reported by a rule.
  FileOffence = Struct.new(:rule, :filepath, :lineno, :text, :message, :highlight) do
    def source_offence = nil
  end
  SegmentOffence = Struct.new(:rule, :filepath, :lineno, :locale, :key, :text, :message, :highlight) do
    def source_offence = nil
  end
  CompareSegmentOffence = Struct.new(*SegmentOffence.members, :source_offence)

  # Base class for Class rule types.
  class Rule
    attr_reader :input, :config

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
    end

    def initialize(input, config = {})
      @input = input
      @config = config
      @offences = []

      self.class.on_init_blocks.each { |b| instance_exec(&b) }
    end

    def describe
      class_desc = " #{description}" if respond_to?(:description) && description
      rule_desc = " #{input.description}" if input.respond_to?(:description) && input.description
      "#{self.class.rule_key}#{class_desc}#{rule_desc}"
    end

    def message
      config["Message"]
    end

    def add_offence(item, message = nil)
      case item
      when File
        add_file_offence(item, message)
      when Segment
        add_segment_offence(item, message)
      else
        raise ArgumentError, "inapplicable offence type #{item.class}: #{item}"
      end
    end

    def add_file_offence(file, msg = nil, lineno: nil, source: nil, highlight: nil)
      @offences << FileOffence.new(
        describe,
        file.filepath,
        lineno,
        source, # don't print the whole file contents in the offence
        msg || message,
        highlight
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
        description,
        segment.filepath,
        segment.lineno,
        segment.locale,
        segment.key,
        segment.text,
        message,
        highlight
      )
    end
  end
end
