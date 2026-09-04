// Shared configuration for this example, and the one file that names all
// three packages it composes: `@rookery/core` for the show rule every page
// applies, `@rookery/todos` for the dependency graph `content/corpus.typ`
// builds and `content/index.typ`/`content/open-only.typ`/`content/wide.typ`
// read back, and `@rookery/slipshow` for the horizontal deck itself.
// slipshow does not import todos, and todos does not import slipshow — this
// project is what composes them, which is the whole point of the example.
//
// `invisible-tags` hides `slip-max-width` from every tag pill: it is this
// page's own presentation instruction, not something a reader looking at a
// todo card needs to see, and rookery renders any tag it does not know how
// to interpret otherwise. There is no `slip-row` tag to hide alongside it —
// every row here comes from `#slipshow`'s `row:`, not from a tag on `#todo`.
#import "@rookery/core:0.1.0": rookery, window
#import "@rookery/todos:0.1.0": todo, todo-graph, graph-slice, layer-of, layers, priority-of, todo-slip-keys, todo-slipshow
#import "@rookery/slipshow:0.1.0": slip, slipshow

#let template(doc) = {
  show: rookery.with(invisible-tags: ("slip-max-width",))
  doc
}
