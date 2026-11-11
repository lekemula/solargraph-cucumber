# frozen_string_literal: true

require 'tmpdir'

RSpec.describe 'Hover on the Cucumber DSL in a step file' do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = File.realpath(dir)
      example.run
    end
  end

  # @return [Hash, Array, nil] the language server's result for the message at the position
  def request(message_class, relpath, code, line, column)
    path = File.join(@root, relpath)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(File.join(@root, '.solargraph.yml'),
               { 'include' => ['features/**/*.feature', 'features/**/*.rb'] }.to_yaml)
    File.write(path, code)
    host = Solargraph::LanguageServer::Host.new
    host.prepare @root
    uri = Solargraph::LanguageServer::UriHelpers.file_to_uri(path)
    host.open uri, code, 1
    params = { 'textDocument' => { 'uri' => uri }, 'position' => { 'line' => line, 'character' => column } }
    message = message_class.new(host, { 'params' => params })
    message.process
    message.result
  end

  # @return [String, nil] the Markdown the language server shows on hover
  def hover(...)
    request(Solargraph::LanguageServer::Message::TextDocument::Hover, ...)&.dig(:contents, :value)
  end

  hooks = <<~RUBY
    Before { }
    After { }
    Around { |scenario, block| block.call }
    AfterStep { }
    World(Module.new)
    ParameterType(name: 'x', regexp: /x/)
  RUBY

  {
    0 => 'Registers a proc that will run before each Scenario.',
    1 => 'Registers a proc that will run after each Scenario.',
    2 => 'Registers a proc that will be wrapped around each scenario.',
    3 => 'Registers a proc that will run after each Step.',
    4 => 'Registers any number of +world\_modules+ (Ruby Modules) and/or a Proc.',
    5 => 'Cucumber::Glue::Dsl#ParameterType'
  }.each do |line, text|
    it "documents #{hooks.lines[line][/\w+/]} with Cucumber's docs" do
      expect(hover('features/support/hooks.rb', hooks, line, 2)).to include(text)
    end
  end
end
