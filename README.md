# I18nLint

Lint your i18n for common problems, so you can be sure your copy doesn't get broken.

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add i18nlint --git='https://github.com/henrahmagix/i18nlint' --ref='0.1.0'
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
git clone https://github.com/henrahmagix/i18nlint
cd i18nlint
gem build i18nlint.gemspec
gem install i18nlint i18nlint-0.1.0.gem
```

## Usage

### Rails

```bash
bin/rails i18nlint
```

This task depends on the Rails task `:environment`, so your application will be loaded, including your I18n configuration, to detect your `I18n.default_locale`.

If there's a `.i18nlint.yml` config file in the root folder, it'll get loaded automatically.

### CLI
As a command-line tool with arguments:
```bash
i18nlint --source=en --config=lint.yml config/locales/*.yml
```

### Ruby
As a Ruby script:
```rb
require "i18nlint"

class MyRule < I18nLint::Rule
  # Define at least one method of :on_file, :on_segment, or :on_segment_comparison.
end
I18nLint.register_rule(MyRule)

offences = I18nLint.lint("path/to/locales/*.{yml,rb,json}", source_locale: "en") # array of offences

# Each offence has the `rule` that added it, the `filepath`, `lineno`, and `text` of the segment or file, and an optional `message` string.
# Segment offences also have `locale` and their full `key`.
# It may also contain a `highlight` array of match offsets pointing to the exact location of the offence in `text`.
# Also if `source_offence` is not nil, it holds the same attributes but about the segment of the same key defined under the source locale.
offences.each do |o|
  puts "#{o.rule} offence at #{o.filepath}:#{o.lineno}"
  puts "#{o.key} in locale: #{o.locale}" unless o.locale && o.key
  puts "compared to #{o.source_offence.key} in source #{o.source_offence.locale}" if o.source_offence
  puts o.text, o.message
end
```

## Configuration

A YAML file named `.i18nlint.yml` is looked for automatically in the current directory and your home directory.

It can be used to add your own rules and configure them.
```yml
require:
  - ./path/to/my/rule
  - ./path/to/other/rule

BuiltIn/Interpolations:
  Enabled: false # disable a built-in that always runs; all rules are enabled by default

MyRules/Amazing: # this matches a class named MyRules::Amazing, defined in any of the `require:` paths above
  Enabled: true
  Exclude:  # every rule config can have a list of Pathname#fnmatch to exclude
    - '*.exclude.yml'

match-segment:
  # A list of `Pattern:` configurations to search for in each individual segment, where each match is an offence.
  - Pattern: 'https://.*\.example.org'
  - Pattern: 'https://.*\.bad.url'
    Exclude:
      - urls-*.yml
  - Pattern: 'Word'
    CaseSensitive: false # makes the Regexp made from Pattern case-insensitive with Regexp::IGNORECASE

match-file:
  # Same as match-segment but passes in a whole file
  - Pattern: something

mismatch-to-source:
  # Same as match-segment but it matches on both translated segments and their
  # source, and then compares the matches: if there are any that are in the
  # source locale but not the translation, or vice versa, an offence is marked.
  - Pattern: '\[[A-Z_]+\]' # some custom tags used in your renderer like `[NAME]`, `[EMAIL_ADDRESS]`, etc.
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec appraisal rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

`bundle exec rake` also runs an example of the CLI tool, and RuboCop.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/henrahmagix/i18nlint. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/henrahmagix/i18nlint/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the I18nLint project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/henrahmagix/i18nlint/blob/main/CODE_OF_CONDUCT.md).
