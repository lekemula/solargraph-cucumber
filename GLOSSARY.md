# Glossary

**Step**
A line in a Gherkin scenario that starts with a keyword (`Given`, `When`, `Then`, `And`, `But`, `*` or a localized
equivalent), followed by the step text. Steps live in `.feature` files.

**Step Definition**
Ruby code that runs when a Step matches: a call such as `Given(expression) { ... }`, usually under
`features/step_definitions/`. The keyword used to define it does not limit which Steps it matches.

**Step Expression**
The pattern a Step Definition matches Step text against. It is either a Cucumber Expression (a string with
placeholders such as `{int}` or `{string}`) or a regular expression.

**Parameter Type**
A named placeholder usable in a Cucumber Expression, such as `{int}`. Cucumber ships built-in Parameter Types, and
projects define their own with `ParameterType(name:, regexp:, ...)`.

**Shadow Source**
A Ruby source the plugin builds to stand in for a non-Ruby document, such as a `.feature` file, so that Solargraph's
Ruby-only machinery can work with it.
