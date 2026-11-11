# frozen_string_literal: true

module Solargraph
  module Cucumber
    # English Step keywords.
    module StepKeyword
      # Markdown shown on hover over a `*` Step, which has no DSL method to borrow docs from
      DOCS = {
        '*' => '**`*`** Step — a Step written as a bullet; Gherkin gives it no Given/When/Then meaning.'
      }.freeze

      # Markdown shown on hover over a Step keyword that defines a Step Definition in a step file. Cucumber defines
      # these methods at runtime, without docs.
      DEFINITION_DOCS = %w[Given When Then And But].to_h do |keyword|
        [keyword, <<~MARKDOWN]
          `#{keyword}(expression) { |*args| … }` — defines a Step Definition.

          Cucumber matches Steps by text only: a Step Definition defined with `Given` also matches `When`, `Then`, `And`, `But` and `*` Steps.
        MARKDOWN
      end.freeze
    end
  end
end
