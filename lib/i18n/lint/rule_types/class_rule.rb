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

        private

        def delegate!
          %i[
            on_file
            on_segment
            on_segment_comparison
          ].each do |m|
            next unless instance.respond_to?(m)

            singleton_class.define_method(m) do |*args, **kwargs, &block|
              instance.public_send(m, *args, **kwargs, &block)
            end
          end
        end
      end
    end
  end
end
