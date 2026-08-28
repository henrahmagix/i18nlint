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

## Custom rules

You can define your own custom rules by defining classes extending `I18nLint::Rule`, and requiring them before I18nLint runs if you're using it in ruby, or linking them under `require:` in the configuration file if you're calling the binary. I18nLint will automatically register all of the subclasses of `I18nLint::Rule` that exist at runtime.

You must define at least one of `on_file`, `on_segment`, or `on_segment_comparison` instance methods. Your rule will get a noop definition for any that is missing.
- `on_file` receives a `I18nLint::File` that has:
  - `filepath` string
  - `parsed` Ruby value of the contents as loaded by I18n
  - `raw` string contents of the file.
- `on_segment` receives a `I18nLint::Segment` that has:
  - `file` (the `I18nLint::File` it's in)
  - `filepath` delegated to `file.filepath`
  - `lineno` integer of the start of the segment definition within the file
  - `key` string of the full segment that you would use in `I18n.t()`
  - `text` string content of the segment
  - if `text` is nil, `value` will be the Ruby value of the segment (it could be an array... if you're putting arrays in your I18n 🤷)
  - `locale` symbol of the segment (or string if i18n gem is < 1.9.1)
  - `source_locale` string of the project source locale
  - `source?` true if the locale is the project source
- `on_segment_comparison` receives two `I18nLint::Segment`s: the first is a translation segment, the second is the same segment in the source locale.

To register an offence, use:
- for `on_file` call `add_file_offence(file, msg = nil, lineno: nil, source: nil, highlight: nil)` where:
  - `file` is the input argument to `on_file`
  - `msg` will be displayed alongside the offence
  - `lineno` is helpful to pass if the issue is isolated to or starts at a certain line in the file
  - `source` should be the string on which the offence occurred, if any
  - `highlight` can be passed as an array of tuples to indicate a range of the file content; if you pass this, you probably don't need to pass the `source`
- for `on_segment` call `add_segment_offence(segment, msg = nil, highlight: nil)` where:
  - `segment` is the input argument to `on_segment`
  - `msg` and `highlight` are the same as above
- for `on_segment_comparison` call `add_segment_compare_offence(segment, source_segment, msg = nil, src_msg = nil, highlight: nil, source_highlight: nil)` where:
  - `segment` and `source_segment` are the input arguments to `on_segment_comparison`
  - `msg` and `highlight` are the same as above
  - `src_msg` and `source_highlight` are the same but attached to the source segment

If you're using Regexp in your rule, more often than not you can pass `highlight: Regexp.last_match.offset(0)` to the add-offence method.

There is a singleton method `on_init` available to add a block that gets evaluated on the rule instance after initialisation, so you can do some one-time setup of configuration values, available as `config`.

A rule can define a `description` instance or class method to describe the rule. Without it, the class name will be used with `::` replaced by `/`.

A message can be passed in per offence, or it will be taken automatically from a `Message` property on the rule configuration.

### Example

```rb
# lib/linters/i18n.rb
module MyI18nRules # the module namespace doesn't matter and is entirely optional
  class DontAllowHelloAndGoodbyeInSameSentence < I18nLint::Rule
    def on_segment(segment)
      segment.text.downcase.scan(/[^.?!]*?[.?!]\s*/) do |sentence|
        if sentence.include?('hello') && sentence.include?('goodbye')
          add_segment_offence(segment, 'Thou Shalt Not greet and leave in the same sentence', highlight: Regexp.last_match.offset(0))
        end
      end
    end
  end
end
```
```yml
# content.yml
en:
  welcome: "One two three. Hello and goodbye! One more finally."
fr:
  welcome: "Un deux trois. Bonjour et au revoir! Encore."
```
```yml
# .i18nlint.yml
require:
  - ./lib/linters/i18n.rb
```
```bash
$ i18nlint --source=en content.yml
Inspecting 1 files
F.
Comparing segments to source EN
.

Offences:

content.yml:2 in en.welcome: MyI18nRules/DontAllowHelloAndGoodbyeInSameSentence: Thou Shalt Not greet and leave in the same sentence
  One two three. Hello and goodbye! One more finally.
                 ^^^^^^^^^^^^^^^^^^^
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
