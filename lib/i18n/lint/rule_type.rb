# frozen_string_literal: true

module I18n
  module Lint
    # Base class for constructors of rules based on configuration type. Consumers can define their own rule types for
    # easily-defined rules, but if the type already exists - e.g. Class, Proc, Regexp - then it'll overwrite. We allow
    # this for consumer customisation, whilst this library offers a base level of rule types for most use cases.
    class RuleType
      attr_reader :rule

      def initialize(config)
        @rule = Rule.new(config)
      end

      def take_offences = rule.take_offences

      def on_file(i18n_file); end
      def on_segment(segment); end
      def on_segment_comparison(segment, source_segment); end
    end
  end
end
