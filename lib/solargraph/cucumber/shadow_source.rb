# frozen_string_literal: true

require 'gherkin/dialect'

module Solargraph
  module Cucumber
    # Turns `.feature` text into a column-preserving Ruby Shadow Source.
    #
    # Every Step line becomes a keyword method call whose string literal starts at the Step text's first column:
    #
    #   "    Given I have 3 cukes"  ->  "    Given\"I have 3 cukes\""
    #
    # The char after the keyword's last identifier char (a space for `Given `) opens the literal, and the closing
    # delimiter replaces the first trailing space or goes one past the end of the line. Every other line becomes a
    # `#` comment of the same length.
    class ShadowSource
      STEP_KEYS = %w[given when then and but].freeze
      NAMESPACE = 'CucumberFeature'
      OPENER = "module #{NAMESPACE};".freeze
      INTERPOLATION = /#[{@$]/

      # @return [String]
      attr_reader :code

      # @param feature [String] the `.feature` text
      # @param namespace [Boolean] wrap the Steps in `module CucumberFeature`, opened on the `Feature:` line
      def initialize(feature, namespace: true)
        @feature = feature
        @namespace = namespace
        @code = transform
      end

      # @param language [String]
      # @return [Array<String>] keyword method names (e.g. `Given`, `Gegeben_sei`, `_`), any dialect when no language
      def self.keyword_methods(language = nil)
        dialects = language ? [Gherkin::Dialect.for(language)] : Gherkin::DIALECTS.keys.map { Gherkin::Dialect.for(_1) }
        dialects.flat_map { |d| step_keywords(d) }.map { method_name(_1) }.uniq
      end

      # @param feature [String] the `.feature` text
      # @return [String, nil] the `# language:` the feature declares
      def self.language(feature)
        feature.each_line do |line|
          next if line.strip.empty?
          return Regexp.last_match(1) if line =~ /\A\s*#\s*language\s*:\s*([\w-]+)/

          return nil unless line.lstrip.start_with?('#')
        end
        nil
      end

      # @param keyword [String] a dialect keyword such as `"Gegeben sei "` or `"Etant donné qu'"`
      # @return [String] the keyword without its last char, identifier-safe
      def self.method_name(keyword)
        keyword.chop.gsub(/[^[:alnum:]_]/, '_')
      end

      # @param dialect [Gherkin::Dialect]
      # @return [Array<String>]
      def self.step_keywords(dialect)
        STEP_KEYS.flat_map { dialect.public_send("#{_1}_keywords") }.uniq
      end

      private

      def transform
        lines = @feature.split("\n", -1)
        dialect = Gherkin::Dialect.for(self.class.language(@feature)) || Gherkin::Dialect.for('en')
        keywords = self.class.step_keywords(dialect).sort_by { -_1.length }
        feature_keywords = dialect.feature_keywords.map { "#{_1}:" }
        doc_string = nil
        opened = false

        out = lines.map do |line|
          stripped = line.lstrip
          indent = line.length - stripped.length

          if doc_string
            doc_string = nil if stripped.start_with?(doc_string)
            next comment(line)
          end
          if stripped.start_with?('"""', '```')
            doc_string = stripped[0, 3]
            next comment(line)
          end
          if @namespace && !opened && feature_keywords.any? { stripped.start_with?(_1) }
            opened = true
            next opener(line)
          end

          keyword = keywords.find { stripped.start_with?(_1) }
          next comment(line) unless keyword

          step(line, indent, keyword) || comment(line)
        end

        out.join("\n") + (opened ? closer : '')
      end

      def comment(line)
        line.empty? ? line : "##{line[1..]}"
      end

      def opener(line)
        rest = line[(OPENER.length + 1)..]
        rest ? "#{OPENER}##{rest}" : OPENER
      end

      def closer
        @feature.end_with?("\n") ? 'end' : "\nend"
      end

      # @return [String, nil] nil when no delimiter fits
      def step(line, indent, keyword)
        text_start = indent + keyword.length
        body = line[text_start..]
        text = body.rstrip
        trailing = body.length - text.length
        name = self.class.method_name(keyword)

        delimiter = delimiter_for(text)
        if delimiter
          head = line[0, indent] + name + delimiter
          close = trailing.positive? ? delimiter + (' ' * (trailing - 1)) : delimiter
          return head + text + close
        end

        # Both quote kinds in the text: borrow 3 indent columns for ` %q` and a delimiter the text lacks
        percent = (%w[| ! ^ ~ `] - text.chars).first
        return nil if indent < 3 || percent.nil? || text.end_with?('\\')

        head = line[0, indent - 3] + name + " %q#{percent}"
        head + text + percent + (' ' * [trailing - 1, 0].max)
      end

      # `"` when the text round-trips through a double-quoted literal, else `'`
      def delimiter_for(text)
        return '"' unless text.include?('"') || text.include?('\\') || text.match?(INTERPOLATION)
        return "'" unless text.include?("'") || text.end_with?('\\')

        nil
      end
    end
  end
end
