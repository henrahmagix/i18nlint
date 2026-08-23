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
      env = ENV.reject { |k, _v| k.match?(/^(BUNDLE|RBENV|GEM_)/) }
      env["PATH"] = env["PATH"].split(":").grep_v(%r{/\.rbenv/versions/}).join(":")

      rubylib = Regexp.union(env.delete("RUBYLIB").split(":"))
      env["RUBYOPT"] = env["RUBYOPT"].shellsplit.grep_v(rubylib).join(" ")

      env
    end
  end
end
