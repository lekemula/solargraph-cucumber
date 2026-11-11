# frozen_string_literal: true

require 'json'
require 'open3'
require 'timeout'

# Drives a real `solargraph stdio` server the way an editor does: initialize, open documents, then request
# definitions, hover and formatting, and collect the diagnostics it publishes. Unlike a Solargraph::Library in-process,
# it catches what only the server does: plugin loading, buffer handling across open documents, logged exceptions.
#
#   ruby script/lsp_probe.rb <project_root> <relpath> <line0> <col0>
#
# opens <relpath> (after the comma-separated relpaths in OPEN_FIRST) and prints what the server answers at that
# position. The server runs with the bundle of <project_root> unless BUNDLE_GEMFILE says otherwise.
class LspProbe
  COMMAND = %w[bundle exec solargraph stdio].freeze

  LANGUAGES = { '.feature' => 'cucumber', '.rb' => 'ruby' }.freeze

  # @return [String]
  attr_reader :root

  # @param root [String] the project directory the server runs in
  # @param env [Hash{String => String}] environment for the server process
  # @param command [Array<String>]
  # @param timeout [Numeric] seconds to wait for each response
  # @return [LspProbe] an initialized server
  def self.start(root, env: {}, command: COMMAND, timeout: 30)
    new(root, env: env, command: command, timeout: timeout).tap(&:initialize_server)
  end

  # @param root [String]
  # @param env [Hash{String => String}]
  # @param command [Array<String>]
  # @param timeout [Numeric]
  def initialize(root, env:, command:, timeout:)
    @root = File.expand_path(root)
    @timeout = timeout
    @id = 0
    @notifications = []
    @stderr = +''
    @stdin, @stdout, stderr, @wait = Open3.popen3(env, *command, chdir: @root)
    @stderr_reader = Thread.new { stderr.each_line { |line| @stderr << line } }
  end

  # @return [void]
  def initialize_server
    request('initialize', processId: Process.pid, rootUri: uri(''), capabilities: {})
    notify('initialized', {})
  end

  # @param relpath [String]
  # @param text [String]
  # @return [void]
  def open(relpath, text: File.read(File.join(root, relpath)))
    notify('textDocument/didOpen',
           textDocument: { uri: uri(relpath), languageId: LANGUAGES.fetch(File.extname(relpath), 'plaintext'),
                           version: 1, text: text })
  end

  # @param relpath [String]
  # @param line [Integer] 0-based
  # @param character [Integer] 0-based
  # @return [Array<Hash>] LSP Locations
  def definition(relpath, line, character)
    Array(request('textDocument/definition', position_params(relpath, line, character)))
  end

  # @param relpath [String]
  # @param line [Integer] 0-based
  # @param character [Integer] 0-based
  # @return [Hash, nil] LSP Hover
  def hover(relpath, line, character)
    request('textDocument/hover', position_params(relpath, line, character))
  end

  # @param relpath [String]
  # @return [Array<Hash>] LSP TextEdits
  def formatting(relpath)
    Array(request('textDocument/formatting',
                  textDocument: { uri: uri(relpath) }, options: { tabSize: 2, insertSpaces: true }))
  end

  # The diagnostics the server last published for a document, waiting for the first publication.
  #
  # @param relpath [String]
  # @return [Array<Hash>] LSP Diagnostics
  def diagnostics(relpath)
    target = uri(relpath)
    Timeout.timeout(@timeout) do
      read_message until published_diagnostics(target)
    end
    published_diagnostics(target)
  end

  # @return [String] what the server logged so far
  def stderr
    @stderr.dup
  end

  # @return [void]
  def stop
    request('shutdown', nil)
    notify('exit', nil)
    @stdin.close
    @wait.join(10) || Process.kill('KILL', @wait.pid)
    @stderr_reader.join(10)
  end

  # @param relpath [String]
  # @return [String]
  def uri(relpath)
    "file://#{File.join(root, relpath)}".chomp('/')
  end

  private

  # @param target [String]
  # @return [Array<Hash>, nil]
  def published_diagnostics(target)
    @notifications.reverse_each do |message|
      next unless message['method'] == 'textDocument/publishDiagnostics' && message['params']['uri'] == target

      return message['params']['diagnostics']
    end
    nil
  end

  # @param relpath [String]
  # @param line [Integer]
  # @param character [Integer]
  # @return [Hash]
  def position_params(relpath, line, character)
    { textDocument: { uri: uri(relpath) }, position: { line: line, character: character } }
  end

  # @param method [String]
  # @param params [Hash, nil]
  # @return [Object] the response's result
  def request(method, params)
    id = (@id += 1)
    write(id: id, method: method, params: params)
    Timeout.timeout(@timeout) do
      loop do
        message = read_message
        next unless message['id'] == id && !message.key?('method')
        raise "#{method} failed: #{message["error"].inspect}" if message['error']

        return message['result']
      end
    end
  end

  # @param method [String]
  # @param params [Hash, nil]
  # @return [void]
  def notify(method, params)
    write(method: method, params: params)
  end

  # Reads the next message, keeping notifications and answering the server's own requests.
  #
  # @return [Hash]
  def read_message
    length = nil
    while (header = @stdout.gets("\r\n"))
      break if header == "\r\n"

      length = header.split(':').last.to_i if header.start_with?('Content-Length')
    end
    raise "solargraph stdio exited:\n#{stderr}" unless length

    message = JSON.parse(@stdout.read(length))
    if message['method'] && message['id']
      write(id: message['id'], result: nil)
    elsif message['method']
      @notifications << message
    end
    message
  end

  # @param payload [Hash]
  # @return [void]
  def write(payload)
    body = JSON.generate(payload.merge(jsonrpc: '2.0'))
    @stdin.write("Content-Length: #{body.bytesize}\r\n\r\n#{body}")
    @stdin.flush
  end
end

if $PROGRAM_NAME == __FILE__
  root, relpath, line, character = ARGV
  abort "usage: #{$PROGRAM_NAME} <project_root> <relpath> <line0> <col0>" unless character

  probe = LspProbe.start(root)
  begin
    ENV.fetch('OPEN_FIRST', '').split(',').each { |other| probe.open(other) }
    probe.open(relpath)
    locations = probe.definition(relpath, line.to_i, character.to_i).map do |location|
      "#{location["uri"].delete_prefix("file://#{probe.root}/")}:#{location["range"]["start"]["line"] + 1}"
    end
    puts "definition: #{locations.inspect}"
    puts "hover: #{probe.hover(relpath, line.to_i, character.to_i)&.dig("contents", "value").inspect}"
    puts "formatting edits: #{probe.formatting(relpath).size}"
    puts "diagnostics: #{probe.diagnostics(relpath).map { |d| "#{d["source"]}: #{d["message"]}" }.uniq.inspect}"
  ensure
    probe.stop
  end
  warn probe.stderr
end
