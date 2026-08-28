# frozen_string_literal: true

require_relative "lib/i18nlint/version"

Gem::Specification.new do |spec|
  spec.name = "i18nlint"
  spec.version = I18nLint::VERSION
  spec.authors = ["Henry Blyth"]
  spec.email = ["blyth.henry@gmail.com"]

  spec.summary = "Linting for your I18n"
  spec.description = spec.summary
  spec.homepage = "https://github.com/henrahmagix/i18nlint"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/v#{spec.version}/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[. bin/ test/ spec/ features/ .git .github appveyor Gemfile gemfiles Appraisal Rakefile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "i18n", "~> 1"

  spec.add_development_dependency "appraisal" # rubocop:disable Gemspec/DevelopmentDependencies
end
