# frozen_string_literal: true

module I18nLint
  # A registered offence as reported by a rule.
  FileOffence = Struct.new(:rule, :filepath, :lineno, :text, :message) do
    def source_offence = nil
  end
  SegmentOffence = Struct.new(:rule, :filepath, :lineno, :locale, :key, :text, :message) do
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
      "#{self.class.rule_key}#{" #{description}" if respond_to?(:description) && description}"
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

    def add_file_offence(file, message = nil, lineno: nil, source: nil)
      @offences << FileOffence.new(
        describe,
        file.filepath,
        lineno,
        source, # don't print the whole file contents in the offence
        make_message(message)
      )
    end

    def add_segment_offence(segment, message = nil)
      @offences << make_segment_offence(describe, segment, make_message(message), SegmentOffence)
    end

    def add_segment_compare_offence(segment, source_segment, message = nil)
      @offences << make_segment_offence(describe, segment, make_message(message), CompareSegmentOffence).tap do |o|
        o.source_offence = make_segment_offence(nil, source_segment, nil, SegmentOffence)
      end
    end

    def take_offences
      @offences
    ensure
      @offences = []
    end

    private

    def make_segment_offence(description, segment, message, offence_class)
      offence_class.new(
        description,
        segment.filepath,
        segment.lineno,
        segment.locale,
        segment.key,
        segment.text,
        message
      )
    end

    def make_message(message)
      message ||= config["Message"]
      message ||= input.description if input.respond_to?(:description) && input.description
      message
    end
  end
end
