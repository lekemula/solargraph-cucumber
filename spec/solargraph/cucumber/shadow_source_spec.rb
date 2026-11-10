# frozen_string_literal: true

require 'solargraph/cucumber/shadow_source'

# PROTOTYPE (proto-shadow-source)
RSpec.describe Solargraph::Cucumber::ShadowSource do
  def shadow(feature, namespace: false)
    described_class.new(feature, namespace: namespace).code
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
end
