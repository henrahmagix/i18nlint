# frozen_string_literal: true

module I18nLint
  module Rules
    module BuiltIn
      # Check I18n interpolations like %{key}.
      class Interpolations < Rule
        enable_by_default true

        on_init do
          interpolation_patterns =
            if ::I18n.config.respond_to?(:interpolation_patterns)
              ::I18n.config.interpolation_patterns
            else
              # This is one union-ed regexp, so we have to split it so we can edit each part individually below.
              ::I18n::INTERPOLATION_PATTERN.source.split(/\|(?=\(\?[-mix]{1,4}:?)/).map do |source|
                source.match(/\(\?[-mix]{1,4}:?(.*)\)/)[1]
              end
            end

          @i18n_interpolation_pattern_allowing_whitespace = Regexp.union(interpolation_patterns.map do |regex|
            regex = regex.source if regex.is_a?(Regexp)
            Regexp.new regex.gsub(/^\\?./, '\0\\s*')
                            .gsub(/\\?.$/, '\\s*\0')
                            .gsub(/\\?[<{]/, '\0\\s*')
          end)
        end

        attr_reader :i18n_interpolation_pattern_allowing_whitespace

        # Look for the configured I18n interpolation pattern with possible spaces inside it; any found that aren't in
        # the known interpolations are an offence.
        def on_segment(segment)
          expected                 = match_with_highlights(segment.text, ::I18n::INTERPOLATION_PATTERN)
          with_possible_whitespace = match_with_highlights(segment.text, i18n_interpolation_pattern_allowing_whitespace)

          xor_highlights!(with_possible_whitespace, expected)

          return if with_possible_whitespace.empty?

          add_segment_offence(segment, "broken", highlight: with_possible_whitespace.map(&:last))
        end

        # Compare interpolations against source; anything extra or missing is an offence.
        def_segment_comparison(
          includes_highlights: true,
          message: lambda do |matches, segment, _source|
            "extra in #{segment.locale}: #{matches.join("; ")}" unless matches.empty?
          end,
          source_message: lambda do |matches, segment, _source|
            "missing in #{segment.locale}: #{matches.join("; ")}" unless matches.empty?
          end
        ) do |segment|
          match_with_highlights(segment.text, ::I18n::INTERPOLATION_PATTERN)
        end
      end
    end
  end
end
