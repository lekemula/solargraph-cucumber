# frozen_string_literal: true

RSpec.describe Solargraph::Cucumber::Walker::BaseProcessor do
  def parse(code)
    RuboCop::AST::ProcessedSource.new(code, RUBY_VERSION.to_f).ast
  end

  let(:walker) { instance_double(Solargraph::Cucumber::Walker) }

  describe '.on_node_type' do
    context 'with a symbol method name' do
      let(:processor_class) do
        Class.new(described_class) do
          attr_reader :entered_nodes

          on_node_type :block, :handle_block

          def handle_block(node)
            (@entered_nodes ||= []) << node
          end
        end
      end

      it 'calls the named method when a matching node is entered' do
        processor = processor_class.new(walker)
        node = parse('it { }')

        processor.dispatch_enter(node)

        expect(processor.entered_nodes).to contain_exactly(node)
      end
    end

    context 'with a block' do
      let(:captured) { [] }
      let(:processor_class) do
        captured_ref = captured
        Class.new(described_class) do
          on_node_type(:block) { |node| captured_ref << node }
        end
      end

      it 'calls the block when a matching node is entered' do
        processor = processor_class.new(walker)
        node = parse('it { }')

        processor.dispatch_enter(node)

        expect(captured).to contain_exactly(node)
      end
    end

    it 'does not call handler for non-matching node types' do
      captured = []
      processor_class = Class.new(described_class) do
        on_node_type(:send) { |node| captured << node }
      end
      processor = processor_class.new(walker)
      node = parse('it { }')

      processor.dispatch_enter(node)

      expect(captured).to be_empty
    end
  end

  describe '.on_node_type_leave' do
    it 'calls handler on leave, not enter' do
      entered = []
      left = []
      processor_class = Class.new(described_class) do
        on_node_type(:block) { |n| entered << n }
        on_node_type_leave(:block) { |n| left << n }
      end
      processor = processor_class.new(walker)
      node = parse('it { }')

      processor.dispatch_enter(node)
      expect(entered).to contain_exactly(node)
      expect(left).to be_empty

      processor.dispatch_leave(node)
      expect(left).to contain_exactly(node)
    end
  end

  describe '.on_node_pattern_enter' do
    it 'calls handler when pattern matches on enter' do
      captured = []
      processor_class = Class.new(described_class) do
        on_node_pattern_enter('(block (send _ :it ...) ...)') { |node| captured << node }
      end
      processor = processor_class.new(walker)

      it_node = parse('it { }')
      processor.dispatch_enter(it_node)
      expect(captured).to contain_exactly(it_node)
    end

    it 'does not call handler when pattern does not match' do
      captured = []
      processor_class = Class.new(described_class) do
        on_node_pattern_enter('(block (send _ :it ...) ...)') { |node| captured << node }
      end
      processor = processor_class.new(walker)

      describe_node = parse('describe { }')
      processor.dispatch_enter(describe_node)
      expect(captured).to be_empty
    end

    it 'passes the pattern captures after the node to a block handler' do
      captured = []
      processor_class = Class.new(described_class) do
        on_node_pattern_enter('(send nil? $_ (str $_))') { |*args| captured << args }
      end
      processor = processor_class.new(walker)

      node = parse("Given('a step')")
      processor.dispatch_enter(node)
      expect(captured).to eq([[node, :Given, 'a step']])
    end

    it 'passes the pattern captures after the node to a named handler' do
      processor_class = Class.new(described_class) do
        attr_reader :captured

        on_node_pattern_enter '(send nil? $_ (str $_))', :handle

        def handle(node, keyword, text)
          @captured = [node.type, keyword, text]
        end
      end
      processor = processor_class.new(walker)

      processor.dispatch_enter(parse("Given('a step')"))
      expect(processor.captured).to eq([:send, :Given, 'a step'])
    end

    it 'does not fire on leave' do
      captured = []
      processor_class = Class.new(described_class) do
        on_node_pattern_enter('(block (send _ :it ...) ...)') { |node| captured << node }
      end
      processor = processor_class.new(walker)

      it_node = parse('it { }')
      processor.dispatch_leave(it_node)
      expect(captured).to be_empty
    end
  end

  describe '.on_node_pattern_leave' do
    it 'calls handler when pattern matches on leave' do
      captured = []
      processor_class = Class.new(described_class) do
        on_node_pattern_leave('(block (send _ :it ...) ...)') { |node| captured << node }
      end
      processor = processor_class.new(walker)

      it_node = parse('it { }')
      processor.dispatch_leave(it_node)
      expect(captured).to contain_exactly(it_node)
    end

    it 'passes the pattern captures after the node' do
      captured = []
      processor_class = Class.new(described_class) do
        on_node_pattern_leave('(send nil? $_ (str $_))') { |*args| captured << args }
      end
      processor = processor_class.new(walker)

      node = parse("Given('a step')")
      processor.dispatch_leave(node)
      expect(captured).to eq([[node, :Given, 'a step']])
    end

    it 'does not fire on enter' do
      captured = []
      processor_class = Class.new(described_class) do
        on_node_pattern_leave('(block (send _ :it ...) ...)') { |node| captured << node }
      end
      processor = processor_class.new(walker)

      it_node = parse('it { }')
      processor.dispatch_enter(it_node)
      expect(captured).to be_empty
    end
  end

  describe '.walked_by' do
    it 'registers the processor with the given walker class only' do
      walker_class = Class.new(Solargraph::Cucumber::Walker)
      processor_class = Class.new(described_class) { walked_by walker_class }

      expect(walker_class.processor_classes).to eq([processor_class])
      expect(Solargraph::Cucumber::Walker.processor_classes).not_to include(processor_class)
    end

    it 'leaves an unbound processor out of every walker' do
      processor_class = Class.new(described_class)

      expect(Solargraph::Cucumber::Walker.processor_classes).not_to include(processor_class)
    end
  end

  describe '#dispatch_enter' do
    it 'ignores non-RuboCop::AST::Node objects' do
      processor_class = Class.new(described_class) do
        on_node_type(:block) { raise 'should not be called' }
      end
      processor = processor_class.new(walker)

      expect { processor.dispatch_enter('not a node') }.not_to raise_error
      expect { processor.dispatch_enter(nil) }.not_to raise_error
    end
  end

  describe '#dispatch_leave' do
    it 'ignores non-RuboCop::AST::Node objects' do
      processor_class = Class.new(described_class) do
        on_node_type_leave(:block) { raise 'should not be called' }
      end
      processor = processor_class.new(walker)

      expect { processor.dispatch_leave('not a node') }.not_to raise_error
      expect { processor.dispatch_leave(nil) }.not_to raise_error
    end
  end
end
