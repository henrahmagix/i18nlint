# frozen_string_literal: true

module SystemInDummyApp
  class << self
    def system(*args, **kwargs)
      Kernel.system(env_for_separate_ruby_process, *args, **kwargs, unsetenv_others: true, chdir:)
    end

    private

    def chdir
      File.expand_path("../dummy", __dir__)
    end

    def env_for_separate_ruby_process
      # We must unset bundler env so the system call can set its own bundle env as per the dummy app folder.
      env = ENV.reject { |k, _v| k.match?(/^(BUNDLE|RBENV)/) }

      if env.key?("RUBYOPT")
        rubyopt = env["RUBYOPT"].shellsplit
        rubylib = env.delete("RUBYLIB").split(":")
        rubyopt.reject! { |cmd| rubylib.any? { cmd.include?(_1) } || cmd.include?("/bundler/setup") }
        env["RUBYOPT"] = rubyopt.join(" ")
      end

      env
    end
  end
end
