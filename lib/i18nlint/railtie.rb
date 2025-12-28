# frozen_string_literal: true

module I18nLint
  # Allow this library to gain I18n configuration from a Rails app.
  class Railtie < ::Rails::Railtie
    rake_tasks do
      desc "Lint your I18n"
      task :i18nlint, [:filepaths] => [:environment] do |_t, args|
        source_locale = Rails.application.config.i18n.default_locale

        filepaths = args[:filepaths]
        filepaths ||= I18n.load_path.select { _1.start_with?(Rails.root.to_s) }

        require "i18nlint/cli"
        I18nLint::CLI.run(["--source=#{source_locale}", *filepaths])
      end
    end
  end
end
