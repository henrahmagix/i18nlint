# frozen_string_literal: true

module MyScope
  class NoComments < I18nLint::Rule
    Comment = Struct.new(:lineno, :raw) do
      def self.all_from_file(file) # rubocop:disable Metrics/MethodLength
        comments = []
        is_block_comment = false
        file.raw.lines.each.with_index(1) do |line, lineno|
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
        comments.reject! { _1.raw.match?(/# ?frozen_string_literal:/) } if file.ruby?
        comments
      end

      def match?(...)
        flattened.match?(...)
      end

      def flattened
        raw.gsub(/^# ?/, "")
      end
    end

    enable_by_default false

    on_init { @allowed_patterns = config["AllowedPatterns"]&.map { Regexp.new(_1) } || [] }
    attr_reader :allowed_patterns

    def description
      return if allowed_patterns.empty?

      "with AllowedPatterns: #{allowed_patterns.map(&:inspect).join(", ")}"
    end

    def on_file(file)
      return unless file.ruby? || file.yaml?
      return unless file.raw.match?(/^# ?/)

      comments = Comment.all_from_file(file)
      comments.reject { |comment| allowed_patterns.any? { comment.match?(_1) } }.each do |comment|
        add_file_offence(file, lineno: comment.lineno, source: comment.raw)
      end
    end
  end
end
