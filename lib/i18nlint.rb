# frozen_string_literal: true

require "i18n"

require_relative "i18nlint/version"
require_relative "i18nlint/error"
require_relative "i18nlint/configuration"
require_relative "i18nlint/highlighters"
require_relative "i18nlint/linter"
require_relative "i18nlint/registry"
require_relative "i18nlint/rule"
require_relative "i18nlint/enumerator"

require_relative "i18nlint/railtie" if defined?(Rails::Railtie)

# Detect various "offences" in your I18n files.
module I18nLint
  def self.lint(filepaths, source_locale: nil)
    linter = Linter.new(filepaths:, source_locale:)
    linter.run
    linter.run_comparison
    linter.offences
  end

  def self.register_rule(rule)
    Registry.register_rule(rule)
  end

  # Basic set of rules.
  module Rules
    # Built-in rules that should suit most use-cases.
    module BuiltIn
      # Match rules have no default configuration, so they must be defined in config to be registered.
      require_relative "i18nlint/rules/built_in/match"
      # Other built-ins aren't much configurable so they're always registered.
      require_relative "i18nlint/rules/built_in/interpolations"
      require_relative "i18nlint/rules/built_in/duplicates"
    end
  end
end
