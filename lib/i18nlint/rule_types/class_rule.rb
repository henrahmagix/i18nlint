# frozen_string_literal: true

module I18nLint
  module RuleTypes
    # Delegate the methods Linter calls to an instance of the given rule.
    class ClassRule < RuleType
      TYPE = Class

      def instance = @instance ||= rule.input.new(rule.input, rule.config)

      def initialize(...)
        super
        delegate!
      end

      def take_offences = instance.take_offences

      LINT_METHODS = %i[
        on_file
        on_segment
        on_segment_comparison
      ].freeze

      # Avoid custom rules that will never get used.
      class WillNeverRun < StandardError
        attr_reader :rule_class

        def initialize(instance)
          @rule_class = instance.class
          super("ClassRule #{rule_class} will never be used: it must respond to one of #{LINT_METHODS}")
        end
      end

      private

      def delegate!
        has_delegated = false

        LINT_METHODS.each do |m|
          next unless instance.respond_to?(m)

          singleton_class.define_method(m) do |*args, **kwargs, &block|
            instance.public_send(m, *args, **kwargs, &block)
          end

          has_delegated = true
        end

        raise WillNeverRun, instance unless has_delegated
      end
    end
  end
end
