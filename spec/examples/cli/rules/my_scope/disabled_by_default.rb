# frozen_string_literal: true

module MyScope
  class DisabledByDefault < I18nLint::Rule
    enable_by_default false

    def on_segment(segment)
      add_offence(segment, "this will always mark an offence, to test enable_by_default")
    end
  end
end
