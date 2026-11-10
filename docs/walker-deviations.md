# Walker deviations from solargraph-rspec

`lib/solargraph/cucumber/walker.rb` and `walker/base_processor.rb` started as a copy of solargraph-rspec PR #33
(commit `ef98a2cc`, `lib/solargraph/rspec/walker.rb` and `walker/base_processor.rb`), with only the namespace renamed.
Each section below is a change the plugin needed since, why it needed it, and whether it looks worth upstreaming.

## 1. Handlers receive the pattern captures

**Change.** A node pattern handler is called with `(node, *captures)`, where the captures are the `$` captures of the
pattern that matched. Patterns without captures still call the handler with just the node, so handlers that take only
`node` keep working; a handler only needs extra parameters when its pattern captures.

**Why.** `ParameterTypeProcessor` needs the `name:` and `regexp:` values of `ParameterType(...)`. With only the node
passed, it repeated its pattern in two more `def_node_matcher`s just to extract them.

**Upstream?** Yes. It is backwards compatible, and it matches how RuboCop cops use `def_node_matcher` captures, which
is the mental model PR #33 aims for. Processors such as `LetMethodProcessor`, which looks the `let` name up again with
`let_symbol_name` after its pattern matched, could take it as a capture instead.

## 2. One processor registry per Walker subclass

**Change.** `Walker#walk!` runs `self.class.processor_classes` instead of `Walker.processor_classes`, and
`BaseProcessor.inherited` no longer registers every subclass on `Walker`. A processor binds itself to the walker it
belongs to with `walked_by SomeWalker`; an unbound processor runs nowhere. The Step Definition index walks step files
with its own `StepDefinitionWalker`, which `StepDefinitionProcessor` and `ParameterTypeProcessor` are bound to.

**Why.** With one global registry every processor runs on every walk. The plugin walks two kinds of source: step files
(Step Definition processors) and Shadow Sources (Shadow Source processors, still to come). Those processor sets must
never cross, or a Step Definition in a Shadow Source would be indexed, and Shadow Source processors would run on step
files.

**Upstream?** Yes, though the need is weaker there. solargraph-rspec has one Walker user today. Its
`SpecConfigurationWalker` hand-rolls a second walk over `RSpec.configure` blocks; moving it onto the Walker would hit
the same crossing. The auto-registration also registers abstract bases such as `SpecWalker::BaseProcessor` as
processors. Upstream could keep its no-wiring feel by having `SpecWalker::BaseProcessor` call `walked_by` for each
subclass in an `inherited` hook.
