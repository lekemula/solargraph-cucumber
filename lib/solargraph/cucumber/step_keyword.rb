# frozen_string_literal: true

module Solargraph
  module Cucumber
    # English Step keywords.
    module StepKeyword
      # Markdown shown on hover over a `*` Step, which has no DSL method to borrow docs from
      DOCS = {
        '*' => '**`*`** Step — a Step written as a bullet; Gherkin gives it no Given/When/Then meaning.'
      }.freeze

      # Keywords Cucumber defines at runtime as aliases of `Cucumber::Glue::Dsl#register_rb_step_definition`
      DEFINITION = %w[Given When Then And But].freeze
    end
  end
end
