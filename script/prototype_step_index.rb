# frozen_string_literal: true

# Runs the StepIndex against a Cucumber project and diffs it with
# `cucumber -P -f usage --dry-run` output.
#
#   bundle exec ruby script/prototype_step_index.rb ~/Projects/open_source/cucumber-sandbox ground_truth.txt

require 'bundler/setup'
require 'solargraph-cucumber'
require 'solargraph/cucumber/step_index'
require 'gherkin'

root = File.expand_path(ARGV.fetch(0))
ground_truth_path = ARGV[1]

index = Solargraph::Cucumber::StepIndex.new(root)
rel = ->(location) { "#{location.filename.delete_prefix("#{root}/")}:#{location.range.start.line + 1}" }

puts '== Parameter Types'
index.parameter_types.each do |pt|
  puts "  {#{pt.name}} #{pt.regexps.inspect}#{" ~approx" if pt.approximate} #{rel[pt.location]}"
end
puts "== Step Definitions (#{index.step_definitions.size})"
index.step_definitions.each do |sd|
  puts "  #{sd.keyword}(#{sd.expression.inspect})#{" ~approx" if sd.approximate} #{rel[sd.location]}"
end

# key "features/x.feature:<step line>" or ":<row line>:<step line>" as cucumber's usage formatter prints it
ours = {}
Dir[File.join(root, 'features', '**', '*.feature')].each do |feature|
  envelopes = Gherkin.from_paths([feature], include_source: false, include_gherkin_document: true,
                                            include_pickles: true).to_a
  doc = envelopes.find(&:gherkin_document).gherkin_document
  lines = {}
  doc.feature.children.each do |child|
    scenario = child.scenario || child.background
    next unless scenario

    scenario.steps.each { |st| lines[st.id] = st.location.line }
    (scenario.respond_to?(:examples) ? scenario.examples : []).each do |ex|
      ex.table_body.each { |row| lines[row.id] = row.location.line }
    end
  end
  file = feature.delete_prefix("#{root}/")
  envelopes.filter_map(&:pickle).each do |pickle|
    pickle.steps.each do |ps|
      step_line, row_line = ps.ast_node_ids.map { |id| lines.fetch(id) }
      key = row_line ? "#{file}:#{row_line}:#{step_line}" : "#{file}:#{step_line}"
      ours[key] = { text: ps.text, defs: index.matches(ps.text).map { |sd| rel[sd.location] } }
    end
  end
end

truth = {}
if ground_truth_path
  current = nil
  File.foreach(ground_truth_path) do |line|
    next unless (loc = line[%r{# (features/\S+)$}, 1])

    if line.start_with?('  ') then (truth[loc] ||= []) << current
    else current = loc
    end
  end
end

puts "\n== Steps (#{ours.size})"
mismatches = 0
ours.sort_by { |k, _| [k[/^[^:]+/], k.split(':')[1..].map(&:to_i)] }.each do |key, result|
  expected = truth[key] || []
  ok = expected.sort == result[:defs].sort
  mismatches += 1 unless ok
  verdict = ok ? 'ok  ' : 'DIFF'
  extra = ok ? '' : "  cucumber: #{expected.inspect}"
  puts "  #{verdict} #{key.ljust(45)} #{result[:text].ljust(48)} -> #{result[:defs].inspect}#{extra}"
end

puts "\n== Compile errors: #{index.errors.map { |rec, e| "#{rel[rec.location]} #{e.class}" }.inspect}"
puts "== #{mismatches} difference(s) from cucumber's usage report" if ground_truth_path
