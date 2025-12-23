# frozen_string_literal: true

module ResetGlobalState
  def self.setup
    @original_rules = I18nLint::Registry.instance_variable_get(:@rules).clone
  end

  def self.reset
    I18nLint::Registry.instance_variable_set(:@rules, @original_rules.clone)
  end
end
