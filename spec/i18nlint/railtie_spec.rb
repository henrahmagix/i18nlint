# frozen_string_literal: true

RSpec.describe "railtie" do
  def system_in_dummy_app(*cmd)
    # We must unset bundler env so the system call can set its own bundle env as per the dummy app folder.
    env_without_bundler = ENV.reject { |k, _v| k.start_with?("BUNDLE") }
    system(env_without_bundler, *cmd, unsetenv_others: true, chdir: "spec/dummy")
  end

  it "takes existing I18n configuration from a Rails app" do
    expect { system_in_dummy_app("bin/rails i18nlint") }
      .to output("").to_stderr_from_any_process
      .and output(<<~OUT).to_stdout_from_any_process
        Inspecting 6 files
        ......
        Comparing segments to source AR
        .

        No offences detected
      OUT
  end
end
