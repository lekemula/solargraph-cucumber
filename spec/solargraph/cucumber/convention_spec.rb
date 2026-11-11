# frozen_string_literal: true

require 'tmpdir'

RSpec.describe Solargraph::Cucumber::Convention do
  it 'is registered as a Solargraph convention' do
    conventions = Solargraph::Convention.class_variable_get(:@@conventions)

    expect(conventions).to include(an_instance_of(described_class))
  end

  describe '#transform_source' do
    it 'turns a .feature file into its Shadow Source' do
      code = described_class.new.transform_source('features/a.feature', "Feature: a\n  Scenario: b\n    Given c\n")

      expect(code).to eq "module CucumberFeature;\n# Scenario: b\n    Given\"c\"\nend"
    end

    it 'leaves other files alone' do
      expect(described_class.new.transform_source('features/a.md', 'Given c')).to be_nil
    end
  end

  describe '#local' do
    let(:root) { Dir.mktmpdir }

    after { FileUtils.remove_entry(root) }

    def write(path, code)
      full = File.join(root, path)
      FileUtils.mkdir_p(File.dirname(full))
      File.write(full, code)
      full
    end

    # @return [Array<String>] "file:line" of each definition, 1-based like an editor shows it
    def definitions_at(feature_path, line, column)
      source = Solargraph::Source.load_string(File.read(feature_path), feature_path)
      pins = Solargraph::ApiMap.new.map(source).clip_at(feature_path, [line, column]).define
      pins.map { |pin| "#{File.basename(pin.location.filename)}:#{pin.location.range.start.line + 1}" }
    end

    it 'returns an empty environ for Ruby files outside a features directory' do
      source_map = Solargraph::SourceMap.load_string('Given(/^a step$/) {}', 'lib/steps.rb')

      expect(described_class.new.local(source_map)).to eq(Solargraph::Convention::Base::EMPTY_ENVIRON)
    end

    it 'returns an empty environ for a feature file loaded before the convention registered' do
      Solargraph::Convention.unregister described_class
      source_map = Solargraph::SourceMap.load_string("Feature: a\n  Scenario: b\n    Given c\n", 'features/a.feature')
      Solargraph::Convention.register described_class

      expect(described_class.new.local(source_map)).to eq(Solargraph::Convention::Base::EMPTY_ENVIRON)
    end

    it 'defines a Step as its Step Definition' do
      write 'features/step_definitions/steps.rb', <<~RUBY
        Given('I have {int} cucumber(s)') { }
        And('the basket belongs to {string}') { }
      RUBY
      feature = write 'features/basket.feature', <<~GHERKIN
        Feature: Basket
          Scenario: x
            Given I have 3 cucumbers
            And the basket belongs to "Aslak"
      GHERKIN

      expect(definitions_at(feature, 2, 15)).to eq ['steps.rb:1']
      expect(definitions_at(feature, 3, 15)).to eq ['steps.rb:2']
    end

    it 'defines Steps of a localized feature, whatever keyword defined them' do
      write 'features/step_definitions/steps.rb', <<~RUBY
        Angenommen('ich habe {int} Gurken') { }
        Then('I should have {int} cucumbers left') { }
      RUBY
      feature = write 'features/german.feature', <<~GHERKIN
        # language: de
        Funktionalität: Gurken
          Szenario: x
            Gegeben sei ich habe 5 Gurken
            Dann I should have 3 cucumbers left
      GHERKIN

      expect(definitions_at(feature, 3, 20)).to eq ['steps.rb:1']
      expect(definitions_at(feature, 4, 15)).to eq ['steps.rb:2']
    end

    it 'falls back to English keywords for a language Gherkin does not know' do
      write 'features/step_definitions/steps.rb', "Given('a') { }\n"
      feature = write 'features/x.feature', "# language: xx\nFeature: x\n  Scenario: y\n    Given a\n"

      expect(definitions_at(feature, 3, 10)).to eq ['steps.rb:1']
    end

    it 'defines an Ambiguous Step as every exact match, and an Undefined Step as nothing' do
      write 'features/step_definitions/steps.rb', <<~'RUBY'
        Given('the basket weighs {int} kg') { }
        Given(/^the basket weighs (\d+) kg$/) { }
        Given("the basket weighs #{UNIT}") { }
        Given("I visit the #{PAGE} page") { }
      RUBY
      feature = write 'features/x.feature', <<~GHERKIN
        Feature: x
          Scenario: y
            Given the basket weighs 2 kg
            When I juggle the cucumbers
            Given I visit the home page
      GHERKIN

      expect(definitions_at(feature, 2, 15)).to eq ['steps.rb:1', 'steps.rb:2']
      expect(definitions_at(feature, 3, 15)).to eq []
      expect(definitions_at(feature, 4, 15)).to eq ['steps.rb:4']
    end

    it 'defines an Outline Step as the union of its Examples rows, exact matches first' do
      write 'features/step_definitions/steps.rb', <<~'RUBY'
        Given('I have {int} cucumbers') { }
        Given('I have many cucumbers') { }
        Given("I have #{AMOUNT} cucumbers") { }
        Given('I have <start> cucumbers in a jar') { }
      RUBY
      feature = write 'features/x.feature', <<~GHERKIN
        Feature: x
          Scenario Outline: y
            Given I have <start> cucumbers

            Examples:
              | start |
              | 3     |
              | many  |
              | 3     |

          Scenario Outline: z
            Given I have <start> cucumbers in a jar
      GHERKIN

      expect(definitions_at(feature, 2, 15)).to eq ['steps.rb:1', 'steps.rb:2']
      expect(definitions_at(feature, 11, 15)).to eq ['steps.rb:4']
    end

    it 'defines a Step written twice once' do
      write 'features/step_definitions/steps.rb', "Given('a') { }\n"
      feature = write 'features/x.feature', "Feature: x\n  Scenario: y\n    Given a\n    Given a\n"

      expect(definitions_at(feature, 3, 10)).to eq ['steps.rb:1']
    end
  end

  describe '#global' do
    it 'returns an empty environ' do
      expect(described_class.new.global(nil)).to eq(Solargraph::Convention::Base::EMPTY_ENVIRON)
    end
  end
end
