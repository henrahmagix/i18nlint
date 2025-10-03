# frozen_string_literal: true

# No on_* methods defined, so it'll never get used.
class BadImplementation < I18nLint::Rule; end

class MissingName < I18nLint::Rule
  # act anonymously
  def self.name = nil
end

class MissingRuleKey < I18nLint::Rule
  def self.rule_key = nil
end

class ExceptionWhenInitialised < I18nLint::Rule
  def initialize(...)
    super
    raise I18nLint::Error, "uh oh, i cannot initialize"
  end
end
