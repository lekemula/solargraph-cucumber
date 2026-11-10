# frozen_string_literal: true

module Solargraph
  module Cucumber
    class Walker
      # Base class for all node processors that handle AST traversal.
      # Subclasses register handlers for specific node types or patterns, which are invoked
      # during tree walking to fire events on the walker.
      class BaseProcessor
        extend RuboCop::AST::NodePattern::Macros

        class << self
          # @return [Hash{Symbol => Symbol, Proc}]
          def node_type_enter_handlers
            @node_type_enter_handlers ||= {}
          end

          # @return [Hash{Symbol => Symbol, Proc}]
          def node_type_leave_handlers
            @node_type_leave_handlers ||= {}
          end

          # @return [Array<Array(Symbol, Symbol, Proc)>]
          def node_pattern_enter_handlers
            @node_pattern_enter_handlers ||= []
          end

          # @return [Array<Array(Symbol, Symbol, Proc)>]
          def node_pattern_leave_handlers
            @node_pattern_leave_handlers ||= []
          end

          # Register a handler for entering nodes of a specific type.
          # @param type [Symbol] The RuboCop node type (e.g., :block, :send)
          # @param method_name [Symbol, nil] Method to call on handler invocation, or nil to use block
          # @return [void]
          def on_node_type(type, method_name = nil, &block)
            node_type_enter_handlers[type] = method_name || block
          end

          # Register a handler for leaving nodes of a specific type.
          # @param type [Symbol] The RuboCop node type
          # @param method_name [Symbol, nil] Method to call on handler invocation, or nil to use block
          # @return [void]
          def on_node_type_leave(type, method_name = nil, &block)
            node_type_leave_handlers[type] = method_name || block
          end

          # Register a handler for entering nodes matching an AST pattern.
          # @param pattern [String] RuboCop AST pattern matching syntax
          # @param method_name [Symbol, nil] Method to call on handler invocation, or nil to use block
          # @return [void]
          def on_node_pattern_enter(pattern, method_name = nil, &block)
            matcher_name = :"__pattern_enter_#{node_pattern_enter_handlers.size}"
            def_node_matcher matcher_name, pattern
            node_pattern_enter_handlers << [matcher_name, method_name || block]
          end

          # Register a handler for leaving nodes matching an AST pattern.
          # @param pattern [String] RuboCop AST pattern matching syntax
          # @param method_name [Symbol, nil] Method to call on handler invocation, or nil to use block
          # @return [void]
          def on_node_pattern_leave(pattern, method_name = nil, &block)
            matcher_name = :"__pattern_leave_#{node_pattern_leave_handlers.size}"
            def_node_matcher matcher_name, pattern
            node_pattern_leave_handlers << [matcher_name, method_name || block]
          end

          # Bind this processor to a walker class, so that walker runs it on every walk.
          # Each Walker subclass keeps its own registry, so processors bound to one never run on another.
          # @param walker_class [Class<Solargraph::Cucumber::Walker>]
          # @return [void]
          def walked_by(walker_class)
            walker_class.register_processor(self)
          end
        end

        # @return [Solargraph::Cucumber::Walker]
        attr_reader :walker

        # @param walker [Solargraph::Cucumber::Walker]
        def initialize(walker)
          @walker = walker
        end

        # Dispatch enter handlers for a given node to all registered handlers.
        # @param node [RuboCop::AST::Node]
        # @return [void]
        def dispatch_enter(node)
          return unless node.is_a?(RuboCop::AST::Node)

          call_handler(node, self.class.node_type_enter_handlers[node.type])
          self.class.node_pattern_enter_handlers.each do |matcher_name, handler|
            send(matcher_name, node) { |*captures| call_handler(node, handler, *captures) }
          end
        end

        # Dispatch leave handlers for a given node to all registered handlers.
        # @param node [RuboCop::AST::Node]
        # @return [void]
        def dispatch_leave(node)
          return unless node.is_a?(RuboCop::AST::Node)

          call_handler(node, self.class.node_type_leave_handlers[node.type])
          self.class.node_pattern_leave_handlers.each do |matcher_name, handler|
            send(matcher_name, node) { |*captures| call_handler(node, handler, *captures) }
          end
        end

        private

        # Invoke a handler with the given node and the captures of the pattern that matched it, if any.
        # @param node [RuboCop::AST::Node]
        # @param handler [Symbol, Proc, nil]
        # @param captures [Array<Object>]
        # @return [void]
        def call_handler(node, handler, *captures)
          return unless handler

          handler.is_a?(Symbol) ? send(handler, node, *captures) : instance_exec(node, *captures, &handler)
        end
      end
    end
  end
end
