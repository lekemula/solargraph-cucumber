# frozen_string_literal: true

require 'tmpdir'

RSpec.describe 'Hover on a Step keyword' do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = File.realpath(dir)
      example.run
    end
  end

  # @return [Hash, Array, nil] the language server's result for the message at the position
  def request(message_class, feature, line, column)
    path = File.join(@root, 'features', 'x.feature')
    FileUtils.mkdir_p(File.dirname(path))
    File.write(File.join(@root, '.solargraph.yml'), { 'include' => ['features/**/*.feature'] }.to_yaml)
    File.write(path, feature)
    host = Solargraph::LanguageServer::Host.new
    host.prepare @root
    uri = Solargraph::LanguageServer::UriHelpers.file_to_uri(path)
    host.open uri, feature, 1
    params = { 'textDocument' => { 'uri' => uri }, 'position' => { 'line' => line, 'character' => column } }
    message = message_class.new(host, { 'params' => params })
    message.process
    message.result
  end

  # @return [String, nil] the Markdown the language server shows on hover
  def hover(...)
    request(Solargraph::LanguageServer::Message::TextDocument::Hover, ...)&.dig(:contents, :value)
  end

  feature = <<~GHERKIN
    Feature: x
      Scenario: y
        Given a
        When b
        Then c
        And d
        But e
        * f
  GHERKIN

  %w[Given When Then And But].each.with_index(2) do |keyword, line|
    it "documents #{keyword} with cucumber-ruby's docs of the method it aliases" do
      text = hover(feature, line, 4)

      expect(text).to include('Registers a new Ruby StepDefinition. This method is aliased')
      expect(text).not_to include("**#{keyword}** Step", 'defines a Step Definition')
    end
  end

  it 'documents * as a bullet Step' do
    expect(hover(feature, 7, 4)).to include(
      '**`*`** Step — a Step written as a bullet; Gherkin gives it no Given/When/Then meaning.'
    )
  end

  it 'defines a Step keyword as the Cucumber method it aliases' do
    result = request(Solargraph::LanguageServer::Message::TextDocument::Definition, feature, 2, 4)

    dsl = File.join(Gem::Specification.find_by_name('cucumber').full_gem_path, 'lib/cucumber/glue/dsl.rb')
    expect(result.map { |location| location[:uri] }).to eq [Solargraph::LanguageServer::UriHelpers.file_to_uri(dsl)]
    target = File.readlines(dsl)[result.first[:range][:start][:line]]
    expect(target).to include('def register_rb_step_definition(regexp, symbol')
  end
end
