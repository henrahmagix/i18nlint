# frozen_string_literal: true

require_relative "i18nlint/version"
require_relative "i18nlint/error"
require_relative "i18nlint/configuration"
require_relative "i18nlint/linter"
require_relative "i18nlint/registry"
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

  # Basic set of rules.
  module Rules
    # Built-in rules that should suit most use-cases.
    module BuiltIn
      require_relative "i18nlint/rules/built_in/match"
      # They get registered by configuration.
    end
  end
end
