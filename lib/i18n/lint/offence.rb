# frozen_string_literal: true

module I18n
  module Lint
    # A registered offence as reported by a rule.
    Offence = Struct.new(:rule, :filepath, :lineno, :locale, :key, :source, :message)
  end
end
