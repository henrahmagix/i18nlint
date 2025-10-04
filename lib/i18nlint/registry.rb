# frozen_string_literal: true

module I18nLint
  # Collect rules.
  class Registry
    @rules = []

    LINT_METHODS = %i[
      on_file
      on_segment
      on_segment_comparison
    ].freeze
    private_constant :LINT_METHODS

    # Avoid custom rules that will never get used.
    class WillNeverRun < StandardError
      attr_reader :rule_class

      def initialize(instance)
        @rule_class = instance.class
        super("Rule #{rule_class} will not be used: it must respond to at least one of " \
              "#{LINT_METHODS.map(&:inspect).join(", ")}")
      end
    end

    class << self
      attr_reader :rules

      def register_rule(rule_class, config = {})
        rule = rule_class.new(config)
        enforce_rule_shape(rule)
        rules << rule
        rule
      end

      private

      def enforce_rule_shape(rule)
        has_methods = false
        LINT_METHODS.each do |m|
          if rule.respond_to?(m)
            has_methods = true
            next
          end

          rule.singleton_class.define_method(m) { |*| nil }
        end

        raise WillNeverRun, rule unless has_methods
      end
    end
  end
end
