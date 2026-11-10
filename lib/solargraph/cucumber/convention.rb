# frozen_string_literal: true

require_relative 'walker'
require_relative 'shadow_source'

module Solargraph
  module Cucumber
    # Links Cucumber steps to their step definitions.
    class Convention < Solargraph::Convention::Base
      # @param filename [String]
      # @param code [String]
      # @return [String, nil] the Shadow Source of a `.feature` file
      def transform_source(filename, code)
        ShadowSource.new(code, namespace: true).code if filename.end_with?('.feature')
      end

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
