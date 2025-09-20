# frozen_string_literal: true

require_relative "lint/version"
require_relative "lint/linter"
require_relative "lint/registry"
require_relative "lint/rule_type"
require_relative "lint/rule"
require_relative "lint/offence"

module I18n
  # Detect various "offences" in your I18n files.
  module Lint
    def self.lint(filepaths, source_locale: nil)
      linter = Linter.new(filepaths:, source_locale:)
      linter.run
      linter.offences.empty? || linter.offences
    end

    def self.register_rule(rule)
      Registry.register_rule(rule)
    end

    def self.register_rule_type(rule_type)
      Registry.register_rule_type(rule_type)
    end

    # How to process a rule based on the type of the rule.
    module RuleTypes
      require_relative "lint/rule_types/class_rule"
      require_relative "lint/rule_types/proc_rule"
      require_relative "lint/rule_types/regexp_rule"
      Registry.register_rule_type(ClassRule)
      Registry.register_rule_type(ProcRule)
      Registry.register_rule_type(RegexpRule)
    end

    # Basic set of rules. TODO: add rules that probably help everyone.
    module Rules
    end
  end
end
