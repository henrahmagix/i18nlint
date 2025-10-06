# frozen_string_literal: true

module I18nLint
  class Error < StandardError; end

  class ErrorOnFile < Error # rubocop:disable Style/Documentation
    def initialize(file, cause)
      super("on file #{file.filepath}:\n  #{cause.class}: #{cause.message}")
    end
  end

  class ErrorOnSegment < Error # rubocop:disable Style/Documentation
    def initialize(segment, cause)
      super("on segment #{segment.key} at #{segment.filepath}:#{segment.lineno}:\n  #{cause.class}: #{cause.message}")
    end
  end

  class ErrorOnSegmentComparison < Error # rubocop:disable Style/Documentation
    def initialize(segment, source_segment, cause)
      super("on segment #{segment.key} at #{segment.filepath}:#{segment.lineno} " \
            "compared to #{source_segment.key} at #{source_segment.filepath}:#{source_segment.lineno}:" \
            "\n  #{cause.class}: #{cause.message}")
    end
  end
end
