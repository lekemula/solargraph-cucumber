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
