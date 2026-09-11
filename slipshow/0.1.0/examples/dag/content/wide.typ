// The sideways-scroll case, deliberately overdone: eight todos forced into
// ONE row, each capped at `max-width: 20em`, so on any screen narrower than
// eight of those side by side the row overflows and scrolls horizontally
// within itself while the rest of the page stays put. This is the only page
// in this example that reaches the controller's row-scroll branch, because
// it is the only one that puts more into a row than a screen can hold.
//
// `content/corpus.typ`'s own `slip-row` tags split these eight across two
// different layers (0 and 1), which is correct for `content/index.typ` but
// wrong for THIS page — an artificial row like this one is a per-page
// presentation choice, not a fact about the graph, so it has to override
// what the note itself carries rather than read it. That is what `#slip`'s
// wrapper is for: `#slip("wide-" + name, row: 0, max-width: 20em)[#window(name)]`
// registers a SECOND, pinned note per todo, under a name derived from but
// distinct from the todo's own — so its own `row`/`max-width` win for this
// page while the wrapped `#window` still shows the real todo underneath
// unchanged.
//
// PINNED, NOT AUTO-ID, and this was tried the other way first and MEASURED
// to break: an auto id is read back from `counter("rheo-ideas-seq")` at the
// position each wrapper is finally placed, but this page decides WHICH
// eight todos to wrap by reading `todo-graph()`'s `.final()` registry —
// itself unresolved until every note on the page (wrapper ideas included)
// has been placed. Typst re-runs layout to converge that circularity, and
// each rerun re-registers the auto-id wrappers from the counter's start,
// landing on the SAME id (`idea:0`) with DIFFERENT content across two runs —
// `@rookery/core` panics on exactly that mismatch. A pinned id sidesteps it:
// the name is a pure function of `name` alone, so every rerun re-emits
// byte-identical content under the same id, which `_registry.update`
// (`core/0.1.0/src/idea.typ`) treats as a re-emission rather than a
// collision.
#import "lib.typ": template, todo-graph, layers, slip, slipshow, window
#show: template

= Eight todos, deliberately crammed into one row

#context {
  let names = layers(todo-graph()).flatten().map(r => r.name).slice(0, 8)
  slipshow(slips: names.map(name => slip("wide-" + name, row: 0, max-width: 20em)[#window(name)]))
}
