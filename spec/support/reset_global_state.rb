# frozen_string_literal: true

module ResetGlobalState
  class << self
    def setup
      @original_rules = I18nLint::Registry.instance_variable_get(:@rules).clone
      @original_classes = I18nLint::Rule.rule_classes.map.to_a
    end

    def reset
      I18nLint::Registry.instance_variable_set(:@rules, @original_rules.clone)
      I18nLint::Rule.rule_classes.delete_if do |klass|
        if @original_classes.include?(klass)
          false
        else
          unload_const!(klass)
          true
        end
      end
    end

    private

    def unload_const!(const)
      return if const.name.to_s.empty?

      begin
        $LOADED_FEATURES.delete Object.const_source_location(const.name)[0]
      rescue NameError
        return
      end

      parent, child_name = parent_const_and_child_name(const)

      parent&.send :remove_const, child_name
    end

    def parent_const_and_child_name(const)
      return if const.name.to_s.empty?

      parts = const.name.split("::")
      child_name = parts.pop
      parent_name = parts.join("::")
      parent = if parent_name.empty?
                 Object
               elsif Object.const_defined?(parent_name)
                 Object.const_get(parent_name)
               end

      [parent, (child_name if parent.const_defined? child_name)]
    end
  end
end
