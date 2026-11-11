# frozen_string_literal: true

module Solargraph
  module Cucumber
    # English Step keywords.
    module StepKeyword
      # Markdown shown on hover over a Step keyword
      DOCS = {
        'Given' => '**Given** Step — puts the system in a known state before the user acts.',
        'When' => '**When** Step — describes the action or event under test.',
        'Then' => '**Then** Step — checks an expected outcome.',
        'And' => '**And** Step — continues the previous Given, When or Then.',
        'But' => '**But** Step — continues the previous step, phrased as a contrast.',
        '*' => '**`*`** Step — a Step written as a bullet; Gherkin gives it no Given/When/Then meaning.'
      }.freeze
    end
  end
end
