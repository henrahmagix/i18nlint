# frozen_string_literal: true

module I18n
  module Lint
    # Ensure cloning an instance also clones its members.
    class CloneableStruct < Struct
      def clone
        super.tap do |new_obj|
          self.class.members.each do |m|
            new_obj.send("#{m}=", send(m).clone)
          end
        end
      end
    end
  end
end
