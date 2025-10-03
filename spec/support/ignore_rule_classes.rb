# frozen_string_literal: true

module RecordInheritedLocation
  def inherited(base)
    base.instance_variable_set(:@_inherited_location, caller_locations(1, 1)[0].absolute_path)
    super
  end
end

I18nLint::Rule.singleton_class.prepend RecordInheritedLocation

module IgnoreRuleClasses
  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def ignore_test_rules(except: "*")
      before do
        allow(I18nLint::Rule).to receive(:rule_classes).and_wrap_original do |m|
          m.call.select do |rule_class|
            (location = rule_class.instance_variable_get(:@_inherited_location)).nil? ||
              Pathname.new(location).fnmatch(except)
          end
        end
      end
    end
  end
end
