# frozen_string_literal: true

require_relative "i18nlint/version"
require_relative "i18nlint/linter"
require_relative "i18nlint/registry"
require_relative "i18nlint/rule_type"
require_relative "i18nlint/rule"
require_relative "i18nlint/enumerator"

# Detect various "offences" in your I18n files.
module I18nLint
  def self.lint(filepaths, source_locale: nil)
    linter = Linter.new(filepaths:, source_locale:)
    linter.run
    linter.run_comparison
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
    require_relative "i18nlint/rule_types/class_rule"
    Registry.register_rule_type(ClassRule)
  end

  # Basic set of rules.
  module Rules
    # Built-in rules that should suit most use-cases.
    module BuiltIn
      require_relative "i18nlint/rules/built_in/match"
      # They get registered by configuration.
    end
  end
end
