# frozen_string_literal: true

module MyScope
  class NoComments < I18n::Lint::Rule
    Comment = Struct.new(:lineno, :raw) do
      def self.all_from_yaml(yaml) # rubocop:disable Metrics/MethodLength
        comments = []
        is_block_comment = false
        yaml.lines.each.with_index(1) do |line, lineno|
          if line.match?(/^# ?/)
            if is_block_comment
              comments.last.raw += line
            else
              comments << new(lineno, line)
              is_block_comment = true
            end
          else
            is_block_comment = false
          end
        end
        comments
      end

      def match?(...)
        flattened.match?(...)
      end

      def flattened
        raw.gsub(/^# ?/, "")
      end
    end

    def on_file(file) # rubocop:disable Metrics/AbcSize
      return if config["AllowedPatterns"].empty? && file.yaml.match?(/^# ?/)

      allowed_patterns = config["AllowedPatterns"].map { Regexp.new(_1) }
      comments = Comment.all_from_yaml(file.yaml)
      comments.reject { |comment| allowed_patterns.any? { comment.match?(_1) } }.each do |comment|
        add_file_offence(file, lineno: comment.lineno, source: comment.raw)
      end
    end
  end
end
