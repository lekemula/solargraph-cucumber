# frozen_string_literal: true

require_relative 'walker'
require_relative 'shadow_source'

module Solargraph
  module Cucumber
    # @!attribute method_name [String] the keyword method the Step calls in the Shadow Source, e.g. `And`
    # @!attribute text [String] the Step text, exactly as written in the `.feature` file
    # @!attribute location [Solargraph::Location] where the Step text sits
    Step = Struct.new(:method_name, :text, :location, keyword_init: true)

    # Walks a Shadow Source with the Shadow Source processors only.
    class ShadowSourceWalker < Walker
      # @return [Array<Step>]
      def steps
        walk!
        context.fetch(:steps, [])
      end
    end
  end
end

require_relative 'node_processors/step_call_processor'
