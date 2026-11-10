# frozen_string_literal: true

require 'solargraph/cucumber/shadow_source'

# PROTOTYPE (proto-shadow-source)
RSpec.describe Solargraph::Cucumber::ShadowSource do
  def shadow(feature, **opts)
    described_class.new(feature, **opts).code
  end

  # @param shadow [String]
  # @return [Array<Array(String, Integer)>] each Step's raw text and start column, read back from the Shadow Source
  def steps_of(shadow)
    ast = Solargraph::Parser.parse(shadow, 'x.feature')
    nodes = []
    walk = lambda do |node|
      next unless node.is_a?(Parser::AST::Node)

      nodes << node.children[2] if node.type == :send && node.children[2]&.type == :str
      node.children.each(&walk)
    end
    walk.call(ast)
    nodes.map { |str| [shadow[str.loc.begin.end_pos...str.loc.end.begin_pos], str.loc.begin.last_column] }
  end

  describe 'transform' do
    let(:feature) do
      <<~GHERKIN
        @tag
        Feature: Cukes

          Scenario: eat
            Given I have 3 cukes
            * I eat 1 cuke
            And the basket belongs to "Aslak"
            Then the label says "Fresh" and is filed under C:\\baskets
            But a sign says "don't panic"
            Then a \#{literal{interpolation}
            And a table:
              | a | b |
            And a doc string:
              """
              Given not a step
              """
      GHERKIN
    end

    it 'keeps line count and the Step text columns' do
      code = shadow(feature)

      expect(code.lines.length).to eq(feature.lines.length)
      feature.lines.zip(code.lines).each do |orig, sh|
        expect(sh.chomp.length).to be_between(orig.chomp.length, orig.chomp.length + 1)
      end
    end

    it 'turns Step lines into keyword calls and everything else into comments' do
      expect(shadow(feature).lines.map(&:chomp)).to eq [
        '#tag',
        '#eature: Cukes',
        '',
        '# Scenario: eat',
        '    Given"I have 3 cukes"',
        '    _"I eat 1 cuke"',
        %q(    And'the basket belongs to "Aslak"'),
        %q(    Then'the label says "Fresh" and is filed under C:\baskets'),
        %q( But %q|a sign says "don't panic"|),
        %q(    Then'a #{literal{interpolation}'),
        '    And"a table:"',
        '#     | a | b |',
        '    And"a doc string:"',
        '#     """',
        '#     Given not a step',
        '#     """'
      ]
    end

    it 'parses as Ruby and gives back every Step text at its original column' do
      expect(steps_of(shadow(feature))).to eq [
        ['I have 3 cukes', 10],
        ['I eat 1 cuke', 6],
        ['the basket belongs to "Aslak"', 8],
        ['the label says "Fresh" and is filed under C:\\baskets', 9],
        ['a sign says "don\'t panic"', 8],
        ['a #{literal{interpolation}', 9],
        ['a table:', 8],
        ['a doc string:', 8]
      ]
    end

    it 'closes the literal in trailing whitespace without growing the line' do
      expect(shadow("  Given trailing   \n")).to eq "  Given\"trailing\"  \n"
    end

    it 'maps i18n keywords to identifier-safe names of the same length' do
      code = shadow("# language: de\nFunktionalität: x\n  Szenario: y\n    Gegeben sei ich habe 5 Gurken\n")

      expect(code.lines[3]).to eq "    Gegeben_sei\"ich habe 5 Gurken\"\n"
    end

    it 'opens a namespace on the Feature line and closes it after the last line' do
      code = shadow("Feature: Cucumber Expressions\n  Scenario: x\n    Given a\n", namespace: true)

      expect(code).to eq "module CucumberFeature;#sions\n# Scenario: x\n    Given\"a\"\nend"
    end
  end

  describe 'go-to-definition without the core hook' do
    let(:feature) do
      <<~GHERKIN
        Feature: Cucumber Expressions
          Scenario: string parameter
            Given I have 3 cucumbers in my basket
            And the basket belongs to "Aslak"
            Given the basket weighs 2 kg
      GHERKIN
    end
    let(:step_def_file) { 'features/step_definitions/basket_steps.rb' }
    let(:location_a) { Solargraph::Location.new(step_def_file, Solargraph::Range.from_to(2, 0, 4, 3)) }
    let(:location_b) { Solargraph::Location.new(step_def_file, Solargraph::Range.from_to(10, 0, 12, 3)) }

    # What the plugin's Convention#local would emit: keyword method pins plus one FactoryParameter per matched
    # Step Definition, here hand-made with fake Step Definition locations.
    def convention(namespace, scope, matches)
      Class.new(Solargraph::Convention::Base) do
        define_method(:local) do |source_map|
          next EMPTY_ENVIRON unless source_map.filename.end_with?('.feature')

          ns_pin = if namespace == 'Object'
                     Solargraph::Pin::ROOT_PIN
                   else
                     Solargraph::Pin::Namespace.new(name: namespace, type: :module, closure: Solargraph::Pin::ROOT_PIN)
                   end
          closure = namespace == 'Object' ? Solargraph::Pin::Namespace.new(name: 'Object') : ns_pin
          methods = %w[Given And].map do |name|
            Solargraph::Pin::Method.new(name: name, closure: closure, scope: scope, visibility: :public).tap do |pin|
              pin.parameters.push Solargraph::Pin::Parameter.new(name: 'text', closure: pin)
            end
          end
          factory = matches.flat_map do |text, locations|
            locations.map do |location|
              Solargraph::Pin::FactoryParameter.new(
                method_name: 'And', method_namespace: namespace, method_scope: scope, param_name: 'text',
                value: text, return_type: Solargraph::ComplexType::VOID, location: location
              )
            end
          end
          Solargraph::Environ.new(pins: (namespace == 'Object' ? [] : [ns_pin]) + methods + factory)
        end
      end
    end

    def define_at(code, line, column, convention)
      Solargraph::Convention.register convention
      source = Solargraph::Source.load_string(code, 'x.feature')
      api_map = Solargraph::ApiMap.new.map(source)
      api_map.clip_at('x.feature', [line, column]).define
    ensure
      Solargraph::Convention.unregister convention
    end

    let(:matches) { { 'the basket belongs to "Aslak"' => [location_a] } }

    it 'resolves a Step on Object' do
      code = described_class.new(feature).code
      pins = define_at(code, 3, 15, convention('Object', :instance, matches))

      expect(pins.map(&:location)).to eq [location_a]
    end

    it 'resolves a Step in a dedicated namespace opened on the Feature line' do
      code = described_class.new(feature, namespace: true).code
      pins = define_at(code, 3, 15, convention('CucumberFeature', :class, matches))

      expect(pins.map(&:location)).to eq [location_a]
    end

    it 'returns one pin per Step Definition when a Step is ambiguous' do
      code = described_class.new(feature).code
      ambiguous = { 'the basket belongs to "Aslak"' => [location_a, location_b] }
      pins = define_at(code, 3, 15, convention('Object', :instance, ambiguous))

      expect(pins.map(&:location)).to eq [location_a, location_b]
    end

    it 'resolves nothing on the keyword or when the cursor is off the Step text' do
      code = described_class.new(feature).code
      conv = convention('Object', :instance, matches)

      expect(define_at(code, 3, 5, conv).map(&:location)).not_to include(location_a)
      expect(define_at(code, 1, 10, conv)).to be_empty
    end
  end
end
