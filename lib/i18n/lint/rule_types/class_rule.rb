# frozen_string_literal: true

module I18n
  module Lint
    module RuleTypes
      # Delegate the methods Linter calls to an instance of the given rule.
      class ClassRule < RuleType
        TYPE = Class

        def instance = rule.config

        def initialize(klass)
          super(klass.new(klass))
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
          def initialize(instance)
            super("ClassRule #{instance} will never be used: it must respond to one of #{LINT_METHODS}")
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
end
