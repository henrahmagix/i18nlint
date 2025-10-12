# frozen_string_literal: true

require "support/system_in_dummy_app"

RSpec.describe "railtie" do
  it "takes existing I18n configuration from a Rails app" do
    expect { SystemInDummyApp.system("bin/rails i18nlint") }
      .to output(<<~OUT).to_stdout_from_any_process
        Inspecting 2 files
        ..
        Comparing segments to source AR
        .

        No offences detected
      OUT
  end
end
