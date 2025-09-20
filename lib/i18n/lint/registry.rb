# frozen_string_literal: true

module I18n
  module Lint
    # Collect rules.
    class Registry
      @rule_types = {}
      @rules = []

      class << self
        attr_reader :rule_types, :rules

        def register_rule_type(rule_type)
          unless rule_type.const_defined?(:TYPE)
            raise ArgumentError, "incomatible rule type class, #{rule_type} must implement ::TYPE"
          end

          type = rule_type::TYPE

          if (existing = rule_types[type])
            warn "#{name}.#{__method__}: #{existing} will no longer be used for #{type}; #{rule_type} is replacing it"
          end
          rule_types[type] = rule_type
        end

        def register_rule(rule)
          if (rule_type = rule_types[rule.class])
            rule = rule_type.new(rule)
            rules << rule
            rule
          else
            raise ArgumentError, "unknown rule type: call #{name}.register_rule_type with a RuleType class that has " \
                                 "TYPE = #{rule.class}"
          end
        end
      end
    end
  end
end
