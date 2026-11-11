# frozen_string_literal: true

require 'tmpdir'

RSpec.describe 'Hover on a Step keyword' do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = File.realpath(dir)
      example.run
    end
  end

  # @return [String, nil] the Markdown the language server shows on hover
  def hover(feature, line, column)
    path = File.join(@root, 'features', 'x.feature')
    FileUtils.mkdir_p(File.dirname(path))
    File.write(File.join(@root, '.solargraph.yml'), { 'include' => ['features/**/*.feature'] }.to_yaml)
    File.write(path, feature)
    host = Solargraph::LanguageServer::Host.new
    host.prepare @root
    uri = Solargraph::LanguageServer::UriHelpers.file_to_uri(path)
    host.open uri, feature, 1
    params = { 'textDocument' => { 'uri' => uri }, 'position' => { 'line' => line, 'character' => column } }
    message = Solargraph::LanguageServer::Message::TextDocument::Hover.new(host, { 'params' => params })
    message.process
    message.result&.dig(:contents, :value)
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

  {
    2 => '**Given** Step — puts the system in a known state before the user acts.',
    3 => '**When** Step — describes the action or event under test.',
    4 => '**Then** Step — checks an expected outcome.',
    5 => '**And** Step — continues the previous Given, When or Then.',
    6 => '**But** Step — continues the previous step, phrased as a contrast.',
    7 => '**`*`** Step — a Step written as a bullet; Gherkin gives it no Given/When/Then meaning.'
  }.each do |line, text|
    it "documents the keyword on line #{line + 1}" do
      expect(hover(feature, line, 4)).to include(text)
    end
  end
end
