# frozen_string_literal: true

module I18n
  module Lint
    # A registered offence as reported by a rule.
    Offence = Struct.new(:rule, :filepath, :lineno, :locale, :key, :source, :message)

    # Base class for Class rule types.
    class Rule
      attr_reader :config

      def initialize(config)
        @config = config
        @offences = []
      end

      def add_offence(item, message = nil)
        case item
        when File
          file_offence(item, message)
        when Segment
          segment_offence(item, message)
        else
          raise ArgumentError, "inapplicable offence type #{item.class}: #{item}"
        end.then { |offence| @offences << offence if offence }
      end

      def file_offence(file, message)
        Offence.new(
          config,
          file.filepath,
          nil, # line
          file.parsed.keys,
          nil, # key
          file.yaml,
          make_message(message)
        )
      end

      def segment_offence(segment, message)
        Offence.new(
          config,
          segment.filepath,
          segment.lineno,
          segment.locale,
          segment.key,
          segment.text,
          make_message(message)
        )
      end

      def take_offences
        @offences
      ensure
        @offences = []
      end

      private

      def make_message(message)
        message ||= config.description if config.respond_to?(:description)
        message
      end
    end
  end
end
