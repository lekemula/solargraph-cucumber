# frozen_string_literal: true

require_relative 'walker'

module Solargraph
  module Cucumber
    # Links Cucumber steps to their step definitions.
    class Convention < Solargraph::Convention::Base
      # @param _yard_map [YardMap]
      # @return [Environ]
      def global(_yard_map)
        EMPTY_ENVIRON
      end

      # @param _source_map [SourceMap]
      # @return [Environ]
      def local(_source_map)
        EMPTY_ENVIRON
      end
    end
  end
end
