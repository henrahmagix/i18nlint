# frozen_string_literal: true

module I18n
  module Lint
    # Base class for constructors of rules based on configuration type. Consumers can define their own rule types
    class RuleType
      def initialize(rule)
        @rule = rule
      end
    end
  end
end
