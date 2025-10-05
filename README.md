# I18nLint

I18nLint your i18n for common problems, so you can be sure your copy doesn't get broken.

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

As a command-line tool:
```bash
i18nlint --source=en --config=.i18nlint.yml config/locales/*.yml
```
with:
```yml
# .i18nlint.yml
require:
  - ./path/to/my/rule
  - ./path/to/other/rule

BuiltIn/Interpolations:
  Enabled: false # disable a built-in that always runs; all rules are enabled by default

My/Rule: # this matches a class named My::Rule, required by any of the `require:` paths above
  Enabled: true
  Exclude:  # every rule config can have a list of Pathname#fnmatch to exclude
    - '*.exclude.yml'

match-segment:
  # A list of `Pattern:` configurations to search for, where each match is an offence.
  - Pattern: 'https://.*\.example.org'
  - Pattern: 'https://.*\.bad.url'
    Exclude:
      - urls-*.yml
  - Pattern: 'Word'
    CaseSensitive: false # makes the Regexp made from Pattern case-insensitive with Regexp::IGNORECASE

match-file: # same as match-segment but passes in a whole file

mismatch-to-source:
  # Same as match-segment but it matches on both translated segments and their
  # source, and then compares the matches: if there are any that are in the
  # source locale but not the translation, or vice versa, an offence is marked.
  - Pattern: '\[[A-Z_]+\]' # some custom tags used in your renderer like `[NAME]`, `[EMAIL_ADDRESS]`, etc.
```

Or in Ruby:
```rb
require "i18nlint"

class MyRule < I18nlint::Rule
  def on_segment(segment)
    if (match = segment.text.match /some kind of match/)
      add_offence(segment, "this is my custom message", highlight: match.offset(0))
    end
  end
end
I18nLint.register_rule(MyRule)

offences = I18nLint.lint("config/locales/*.yml", source_locale: "en") # array of offences

# Each offence has the `rule` that added it, the `filepath`, `lineno`, and `text` of the segment, and an optional `message` string.
# It may also contain a `highlight` array of match offsets pointing to the exact location of the offence in `text`.
# Also if `source_offence` is not nil, it holds the same attributes but about the source segment i.e. the source French for `source_locale: "fr"` or the source English for `source_locale: "en"`.
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
